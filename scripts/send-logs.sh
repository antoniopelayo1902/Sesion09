#!/usr/bin/env bash
#
# send-logs.sh
# Sube todos los batches a s3://<BUCKET>/input/ esperando N segundos entre
# cada uno (usa aws s3 y sleep).
#
# Uso:
#   ./send-logs.sh <segundos_de_espera> [directorio_batches]
#
# Ejemplo:
#   ./send-logs.sh 30
#
set -euo pipefail

WAIT_SECONDS="${1:-30}"
BATCH_DIR="${2:-batches}"
BUCKET="${BUCKET:-logging}"

if ! [[ "$WAIT_SECONDS" =~ ^[0-9]+$ ]]; then
  echo "ERROR: el primer argumento debe ser el numero de segundos a esperar." >&2
  echo "Uso: ./send-logs.sh <segundos> [directorio_batches]" >&2
  exit 1
fi

if [[ ! -d "$BATCH_DIR" ]]; then
  echo "ERROR: no existe el directorio de batches '${BATCH_DIR}'." >&2
  echo "Primero corre: ./split-log.sh" >&2
  exit 1
fi

shopt -s nullglob
batches=( "${BATCH_DIR}"/openssh-*.log )
shopt -u nullglob

if [[ "${#batches[@]}" -eq 0 ]]; then
  echo "ERROR: no se encontraron batches (openssh-*.log) en '${BATCH_DIR}'." >&2
  exit 1
fi

total="${#batches[@]}"
echo "Subiendo ${total} batches a s3://${BUCKET}/input/ con ${WAIT_SECONDS}s de espera entre cada uno."

i=0
for batch in "${batches[@]}"; do
  i=$(( i + 1 ))
  name="$(basename "$batch")"
  echo "[${i}/${total}] aws s3 cp ${name} -> s3://${BUCKET}/input/${name}"
  aws s3 cp "$batch" "s3://${BUCKET}/input/${name}"

  # No esperamos despues del ultimo batch
  if [[ "$i" -lt "$total" ]]; then
    echo "        durmiendo ${WAIT_SECONDS}s..."
    sleep "$WAIT_SECONDS"
  fi
done

echo "Terminado. Revisa los resultados en s3://${BUCKET}/output/"
