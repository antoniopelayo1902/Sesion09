"""
Lambda: logging-system

Trigger: se dispara cuando se escribe un objeto .log en s3://<bucket>/input/.
Accion : descarga el .log, parsea cada linea con el formato de OpenSSH,
         genera un CSV con las columnas [timestamp, hostname, program, pid, log]
         y lo sube a s3://<bucket>/output/ con el MISMO nombre pero extension .csv.

Ejemplo de linea de entrada:
    Dec 10 06:55:46 LabSZ sshd[24200]: Invalid user webmaster from 173.234.31.186

Se convierte en:
    timestamp        -> Dec 10 06:55:46
    hostname         -> LabSZ
    program          -> sshd
    pid              -> 24200
    log              -> Invalid user webmaster from 173.234.31.186
"""

import csv
import io
import os
import re
import urllib.parse

import boto3

s3 = boto3.client("s3")

# <mes> <dia> <hh:mm:ss> <hostname> <program>[<pid>]: <mensaje>
# El bloque [pid] es opcional: algunas lineas de syslog no lo traen.
LINE_RE = re.compile(
    r"^(?P<timestamp>[A-Z][a-z]{2}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})\s+"
    r"(?P<hostname>\S+)\s+"
    r"(?P<program>[^\[:\s]+)"
    r"(?:\[(?P<pid>\d+)\])?:\s?"
    r"(?P<log>.*)$"
)

CSV_HEADER = ["timestamp", "hostname", "program", "pid", "log"]


def parse_line(line):
    """Devuelve una lista [timestamp, hostname, program, pid, log] o None."""
    line = line.rstrip("\n").rstrip("\r")
    if not line.strip():
        return None

    match = LINE_RE.match(line)
    if not match:
        # Linea que no cumple el formato: la guardamos completa en la
        # columna log para no perder informacion.
        return ["", "", "", "", line]

    d = match.groupdict()
    return [
        d["timestamp"],
        d["hostname"],
        d["program"],
        d["pid"] or "",
        d["log"],
    ]


def to_csv(content):
    """Convierte el contenido de un .log a texto CSV."""
    buffer = io.StringIO()
    writer = csv.writer(buffer)
    writer.writerow(CSV_HEADER)

    for raw_line in content.splitlines():
        row = parse_line(raw_line)
        if row is not None:
            writer.writerow(row)

    return buffer.getvalue()


def output_key(input_key):
    """input/openssh-123.log  ->  output/openssh-123.csv"""
    base = os.path.basename(input_key)
    if base.endswith(".log"):
        base = base[: -len(".log")]
    return f"output/{base}.csv"


def lambda_handler(event, context):
    processed = []

    for record in event.get("Records", []):
        bucket = record["s3"]["bucket"]["name"]
        key = urllib.parse.unquote_plus(record["s3"]["object"]["key"])

        # Solo procesamos archivos .log dentro de input/
        if not key.startswith("input/") or not key.endswith(".log"):
            print(f"Ignorando objeto fuera de alcance: {key}")
            continue

        print(f"Procesando s3://{bucket}/{key}")
        obj = s3.get_object(Bucket=bucket, Key=key)
        content = obj["Body"].read().decode("utf-8", errors="replace")

        csv_text = to_csv(content)
        out_key = output_key(key)

        s3.put_object(
            Bucket=bucket,
            Key=out_key,
            Body=csv_text.encode("utf-8"),
            ContentType="text/csv",
        )
        print(f"CSV guardado en s3://{bucket}/{out_key}")
        processed.append(out_key)

    return {
        "statusCode": 200,
        "processed": processed,
    }
