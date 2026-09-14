#!/usr/bin/env bash
#
# teardown.sh
# Limpia los recursos creados durante la actividad para no dejar costos.
# Vacia y elimina el bucket S3. Opcionalmente elimina la funcion Lambda si
# defines LAMBDA_NAME.
#
# Uso:
#   ./teardown.sh
#   BUCKET=mi-bucket LAMBDA_NAME=logging-system ./teardown.sh
#
set -euo pipefail

BUCKET="${BUCKET:-logging}"
LAMBDA_NAME="${LAMBDA_NAME:-}"

echo "ADVERTENCIA: esto va a ELIMINAR el bucket '${BUCKET}' y todo su contenido."
read -r -p "Escribe 'si' para continuar: " confirm
if [[ "$confirm" != "si" ]]; then
  echo "Cancelado."
  exit 0
fi

if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo "Vaciando s3://${BUCKET} ..."
  aws s3 rm "s3://${BUCKET}" --recursive
  echo "Eliminando bucket ..."
  aws s3api delete-bucket --bucket "$BUCKET"
  echo "Bucket eliminado."
else
  echo "El bucket '${BUCKET}' no existe o no es accesible. Nada que borrar."
fi

if [[ -n "$LAMBDA_NAME" ]]; then
  echo "Eliminando funcion Lambda '${LAMBDA_NAME}' ..."
  aws lambda delete-function --function-name "$LAMBDA_NAME" || true
  echo "Lambda eliminada (si existia)."
fi

echo "Teardown completo."
