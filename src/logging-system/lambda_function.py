import os
import re
import urllib.parse
import boto3

s3 = boto3.client("s3")

LINE_RE = re.compile(
    r"^(?P<timestamp>[A-Z][a-z]{2}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})\s+"
    r"(?P<hostname>\S+)\s+"
    r"(?P<program>[^\[:\s]+)"
    r"(?:\[(?P<pid>\d+)\])?:\s?"
    r"(?P<log>.*)$"
)

def parse_line(line):
    """Devuelve un diccionario con los datos parseados o None."""
    line = line.rstrip("\n").rstrip("\r")
    if not line.strip():
        return None

    match = LINE_RE.match(line)
    if not match:
        return {
            "timestamp": "UNKNOWN",
            "hostname": "UNKNOWN",
            "program": "UNKNOWN",
            "pid": "",
            "log": line
        }

    d = match.groupdict()
    d["pid"] = d["pid"] or ""
    return d

def lambda_handler(event, context):
    # Inicializamos la lista que contendrá todas las líneas procesadas
    parsed_lines = []

    for record in event.get("Records", []):
        bucket = record["s3"]["bucket"]["name"]
        key = urllib.parse.unquote_plus(record["s3"]["object"]["key"])

        if not key.startswith("input/") or not key.endswith(".log"):
            print(f"Ignorando objeto fuera de alcance: {key}")
            continue

        print(f"Descargando batch s3://{bucket}/{key}")
        obj = s3.get_object(Bucket=bucket, Key=key)
        content = obj["Body"].read().decode("utf-8", errors="replace")

        # Separar el batch en líneas individuales
        for raw_line in content.splitlines():
            parsed_data = parse_line(raw_line)
            if parsed_data:
                parsed_data["id"] = f"{key}-{len(parsed_lines)}" # Generamos un ID único básico para DynamoDB
                parsed_lines.append(parsed_data)

    # La Lambda termina devolviendo el arreglo completo. 
    # Step Functions tomará este arreglo como input para su estado 'Map'.
    return parsed_lines