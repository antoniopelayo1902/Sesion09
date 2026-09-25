#!/usr/bin/env bash
#
# create-s3-bucket.sh
# Crea el bucket de S3 para la actividad y prepara los "folders" input/ y output/.
#
# Nota: los nombres de bucket en S3 son GLOBALES y unicos. "logging" casi
# seguro ya existe, por eso puedes sobreescribir el nombre con la variable
# de entorno BUCKET, por ejemplo:
#   BUCKET=logging-tu-equipo-123 ./create-s3-bucket.sh
#
# Uso:
#   ./create-s3-bucket.sh
#
set -euo pipefail

BUCKET="${BUCKET:-desarrollo-nube-2026}"
REGION="${AWS_REGION:-us-east-1}"

echo "Creando bucket '${BUCKET}' en la region '${REGION}'..."

if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo "El bucket '${BUCKET}' ya existe y es accesible. Continuo."
else
  if [[ "$REGION" == "us-east-1" ]]; then
    # us-east-1 NO acepta LocationConstraint
    aws s3api create-bucket --bucket "$BUCKET" --region "$REGION"
  else
    aws s3api create-bucket \
      --bucket "$BUCKET" \
      --region "$REGION" \
      --create-bucket-configuration LocationConstraint="$REGION"
  fi
  echo "Bucket creado."
fi

# S3 no tiene folders reales, pero creamos los prefijos con objetos vacios
# para que se vean en la consola.
aws s3api put-object --bucket "$BUCKET" --key "input/"  >/dev/null
aws s3api put-object --bucket "$BUCKET" --key "output/" >/dev/null

echo "Prefijos listos:"
echo "  s3://${BUCKET}/input/"
echo "  s3://${BUCKET}/output/"
