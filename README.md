# Log Processing System (Serverless)

Actividad de la Sesión 9 — Módulo 5: Desarrollo serverless con API REST
(Desarrollo en la Nube — ITESO).

Sistema **serverless** basado en AWS Lambda que consume logs de OpenSSH en
batches de ~1KB, los procesa y guarda el resultado como CSV en S3.

```
s3://<bucket>/input/   ->   Lambda (logging-system)   ->   s3://<bucket>/output/
        openssh-<ts>.log                                          openssh-<ts>.csv
```

## Arquitectura

1. Un script parte el log de origen en batches de ~1KB (`openssh-<timestamp>.log`).
2. Otro script sube los batches a `s3://<bucket>/input/` esperando N segundos entre cada uno.
3. Al escribirse un `.log` en `input/`, un **evento de S3** dispara la Lambda.
4. La Lambda descarga el `.log`, lo parsea, genera un CSV y lo sube a `s3://<bucket>/output/`
   con el **mismo nombre** pero extensión `.csv`.

### Formato del CSV

```
timestamp, hostname, program, pid, log
```

Ejemplo. Esta línea de entrada:

```
Dec 10 06:55:46 LabSZ sshd[24200]: Invalid user webmaster from 173.234.31.186
```

se convierte en:

```
timestamp,hostname,program,pid,log
Dec 10 06:55:46,LabSZ,sshd,24200,Invalid user webmaster from 173.234.31.186
```

## Estructura del proyecto

```
Sesion09/
├── README.md
├── start_logging.sh            # punto de entrada: ./start_logging.sh 30
├── scripts
│   ├── split-log.sh            # parte el log en batches de ~1KB
│   ├── create-s3-bucket.sh     # crea el bucket S3 y los prefijos input/ output/
│   ├── send-logs.sh            # sube los batches a S3 esperando N segundos
│   ├── package-lambda.sh       # empaqueta la Lambda en un .zip
│   └── teardown.sh             # limpia los recursos (borra el bucket)
└── src
    └── logging-system
        ├── lambda_function.py  # handler de la Lambda (parser -> CSV)
        └── requirements.txt
```

## Requisitos

- [AWS CLI](https://docs.aws.amazon.com/cli/) configurado (`aws configure`).
- `bash`, `curl`, `zip`.
- Python 3.11+ (runtime sugerido para la Lambda).

## Uso paso a paso

### 0. Descargar el log de ejemplo

```bash
curl -L -o OpenSSH_2k.log \
  https://raw.githubusercontent.com/logpai/loghub/master/OpenSSH/OpenSSH_2k.log
```

### 1. Partir el log en batches de ~1KB

```bash
./scripts/split-log.sh OpenSSH_2k.log batches 1024
```

Genera archivos `batches/openssh-<timestamp>.log`.

### 2. Crear el bucket S3

Los nombres de bucket en S3 son globales y únicos, así que `logging` casi seguro
ya está tomado. Usa la variable `BUCKET` para darle un nombre único:

```bash
BUCKET=logging-mi-equipo-123 ./scripts/create-s3-bucket.sh
```

### 3. Desplegar la Lambda

Empaqueta el código:

```bash
./scripts/package-lambda.sh   # genera dist/logging-system.zip
```

Luego, desde la consola de AWS o la CLI:

- Crea una función Lambda (runtime Python 3.11) con el handler
  `lambda_function.lambda_handler`.
- Sube `dist/logging-system.zip`.
- Dale a su rol permisos de `s3:GetObject` sobre `input/*` y `s3:PutObject`
  sobre `output/*` del bucket.
- Configura un **trigger de S3**: evento `PUT` (todos los objetos creados),
  prefijo `input/`, sufijo `.log`.

> Importante: el trigger debe filtrar por prefijo `input/` y sufijo `.log`
> para evitar que la Lambda se dispare a sí misma al escribir en `output/`.

### 4. Enviar los batches y ver los resultados

```bash
./start_logging.sh 30        # sube cada batch con 30s de espera entre uno y otro
```

Revisa la salida:

```bash
aws s3 ls s3://$BUCKET/output/
```

### 5. Limpiar todo

```bash
BUCKET=logging-mi-equipo-123 LAMBDA_NAME=logging-system ./scripts/teardown.sh
```

## Variables de entorno

| Variable      | Default     | Descripción                                  |
|---------------|-------------|----------------------------------------------|
| `BUCKET`      | `logging`   | Nombre del bucket S3.                         |
| `AWS_REGION`  | `us-east-1` | Región para crear el bucket.                  |
| `LAMBDA_NAME` | (vacío)     | Nombre de la Lambda a borrar en el teardown.  |
