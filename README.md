# Sistema Serverless de Procesamiento de Logs en AWS

Este proyecto implementa una arquitectura orientada a eventos (Event-Driven) y totalmente desacoplada en AWS para la ingesta, clasificación y consulta asíncrona de logs de servidores (específicamente logs de OpenSSH). 

El sistema procesa fragmentos de logs en tiempo real, detecta automáticamente firmas de ataques (como intentos de intrusión) mediante expresiones regulares, y almacena los datos en bases de datos NoSQL optimizadas para ser consumidas a través de una API HTTP pública.

## Arquitectura del Sistema

El sistema se divide en tres fases principales que operan de manera independiente:

### 1. Fase de Ingesta (Origen de los datos)
* **Amazon S3:** Actúa como el punto de entrada. Recibe archivos de texto plano divididos en lotes (batches) en el prefijo `input/`. Su única responsabilidad es almacenar el archivo y generar un evento.
* **AWS Lambda (`parse_batch`):** Función de cómputo efímero que extrae el archivo de S3, obtiene el metadato de la hora de llegada (`LastModified`) y procesa el texto línea por línea convirtiendo cadenas de texto sin estructura en objetos JSON legibles.

### 2. Fase de Orquestación y Almacenamiento (El cerebro y la memoria)
* **AWS Step Functions (`OrquestadorDeLogs`):** Motor de flujo de trabajo que toma las decisiones de enrutamiento:
  * Utiliza un estado **Map** para iterar sobre el arreglo de líneas devuelto por la Lambda.
  * Utiliza un estado **Choice** para evaluar el contenido de cada línea. Si detecta "Invalid user" o "POSSIBLE BREAK-IN ATTEMPT", enruta el dato hacia la tabla de alertas. De lo contrario, lo envía a la tabla de logs normales.
  * Implementa bloques **Retry** (Reintentos) para manejar excepciones de escritura sin que el sistema colapse (e.g., `ProvisionedThroughputExceededException`).
* **Amazon DynamoDB:** Base de datos NoSQL clave-valor.
  * **Tabla `SecurityAlerts`:** Almacena las alertas. Diseñada con una llave de partición `alert_status` que permite extraer todas las amenazas activas con una sola consulta directa.
  * **Tabla `Logs`:** Almacena el tráfico normal. Implementa un **Índice Secundario Global (GSI)** (`RecentLogsIndex`) utilizando la hora de llegada a S3 como Sort Key, lo que permite a la base de datos ordenar los registros cronológicamente de forma nativa sin escaneos costosos.

### 3. Fase de Consulta (Exposición de datos)
* **Amazon API Gateway (HTTP API):** Es la puerta frontal del sistema. Expone URLs públicas (`/logs` y `/alerts`) y traduce las peticiones web en eventos.
* **AWS Lambda de Lectura (`get_logs`, `get_alerts`):** Funciones intermediarias que reciben la petición de la API, ejecutan un `Query` eficiente en DynamoDB (limitando resultados y usando `ScanIndexForward=False` para orden descendente) y retornan una respuesta JSON estructurada al cliente.

---

## Estructura del Repositorio

```text
.
├── batches/                      # Carpeta generada automáticamente con fragmentos de logs
├── build/                        # Directorio de construcción
├── dist/                         # Empaquetados (.zip) de las funciones Lambda
├── scripts/
│   ├── create-dynamodb-tables.sh # Creación de tablas e índices en DynamoDB
│   ├── create-s3-bucket.sh       # Creación del bucket de ingesta
│   ├── package-lambda.sh         # Empaquetado de la función de ingesta
│   ├── send-logs.sh              # Envío de batches a S3
│   ├── split-log.sh              # División del archivo original en batches
│   └── teardown.sh               # Limpieza de recursos iniciales
├── src/
│   ├── api/
│   │   ├── get_alerts.py         # Lambda para consultar alertas de seguridad
│   │   └── get_logs.py           # Lambda para consultar logs normales
│   └── logging-system/
│       ├── lambda_function.py    # Lambda para procesar archivos de S3
│       └── requirements.txt      # Dependencias de Python
├── venv/                         # Entorno virtual de Python
├── .gitignore                    # Archivos y carpetas ignorados por git
├── OpenSSH_2k.log                # Archivo original de logs de muestra
├── README.md                     # Documentación del proyecto
└── start_logging.sh              # Wrapper para iniciar la simulación en tiempo real
```

---

## Requisitos Previos

* AWS CLI configurado con credenciales válidas y permisos suficientes (ej. `LabRole`).
* Python 3.11+.
* Entorno virtual de Python con `boto3` instalado.
* Archivo de muestra `OpenSSH_2k.log` (ver sección de Pruebas).

---

## Instrucciones de Despliegue

### 1. Preparación de Infraestructura
Ejecuta los scripts para aprovisionar las bases de datos (en `us-west-2`) y el almacenamiento en la nube:
```bash
./scripts/create-dynamodb-tables.sh
./scripts/create-s3-bucket.sh
```
*Nota: Asegúrate de que el nombre del bucket dentro de los scripts (`desarrollo-nube-2026` u otro) sea globalmente único.*

### 2. Despliegue de Lambdas
Empaqueta y crea las tres funciones Lambda requeridas usando la AWS CLI. Reemplaza `TU_CUENTA` por tu ID de cuenta de AWS:

```bash
# Empaquetado y creación de la Lambda de Ingesta
./scripts/package-lambda.sh
aws lambda create-function --function-name parse_batch --runtime python3.11 --role arn:aws:iam::TU_CUENTA:role/LabRole --handler lambda_function.lambda_handler --zip-file fileb://dist/logging-system.zip

# Empaquetado y creación de las Lambdas de Consulta
zip -j dist/get_alerts.zip src/api/get_alerts.py
zip -j dist/get_logs.zip src/api/get_logs.py

aws lambda create-function --function-name get_alerts --runtime python3.11 --role arn:aws:iam::TU_CUENTA:role/LabRole --handler get_alerts.lambda_handler --zip-file fileb://dist/get_alerts.zip
aws lambda create-function --function-name get_logs --runtime python3.11 --role arn:aws:iam::TU_CUENTA:role/LabRole --handler get_logs.lambda_handler --zip-file fileb://dist/get_logs.zip
```

### 3. Orquestador (Step Functions)
1. Ve a la consola de AWS Step Functions.
2. Crea una nueva State Machine utilizando código JSON.
3. Define la lógica incluyendo los estados `Task`, `Map` y `Choice` para enrutar los datos procesados por `parse_batch` hacia `Logs` o `SecurityAlerts`.
4. Asigna el rol de ejecución adecuado (`LabRole`).

### 4. Exposición (API Gateway)
1. Crea una **HTTP API** en la consola de API Gateway.
2. Configura dos rutas GET conectadas a sus respectivas Lambdas mediante integraciones:
   * `GET /alerts` -> Integración con Lambda `get_alerts`
   * `GET /logs` -> Integración con Lambda `get_logs`
3. Despliega la API en el stage `$default` para obtener la URL de invocación.

---

## Pruebas y Simulación

1. **Descargar el archivo base de logs (si no existe):**
   ```bash
   curl -L -o OpenSSH_2k.log [https://raw.githubusercontent.com/logpai/loghub/master/OpenSSH/OpenSSH_2k.log](https://raw.githubusercontent.com/logpai/loghub/master/OpenSSH/OpenSSH_2k.log)
   ```
2. **Dividir los logs en batches:**
   ```bash
   chmod +x scripts/split-log.sh
   ./scripts/split-log.sh
   ```
3. **Simular tráfico en tiempo real:**
   Inicia el simulador para subir archivos intermitentemente al bucket S3:
   ```bash
   ./start_logging.sh
   ```
4. **Verificar los resultados a través de la API:**
   Abre un navegador y realiza consultas a los endpoints desplegados:
   * Logs normales (ej. últimos 5 registros): `https://TU_API_URL/logs?top=5`
   * Alertas detectadas: `https://TU_API_URL/alerts`

---

## Limpieza de Recursos (Teardown)
Para evitar costos residuales o mantener el laboratorio en cero, elimina la infraestructura generada:
```bash
# Eliminar tablas de DynamoDB
aws dynamodb delete-table --table-name Logs
aws dynamodb delete-table --table-name SecurityAlerts

# Vaciar y eliminar el bucket S3 (reemplaza TU_BUCKET por el nombre real)
aws s3 rm s3://TU_BUCKET --recursive
aws s3api delete-bucket --bucket TU_BUCKET

# Eliminar Lambdas
aws lambda delete-function --function-name parse_batch
aws lambda delete-function --function-name get_alerts
aws lambda delete-function --function-name get_logs

# Eliminar API Gateway (reemplaza TU_API_ID por el ID real)
aws apigatewayv2 delete-api --api-id TU_API_ID
```
*(Elimina la máquina de estados manualmente desde la consola web de Step Functions).*