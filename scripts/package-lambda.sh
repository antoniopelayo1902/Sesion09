#!/usr/bin/env bash
#
# package-lambda.sh
# Empaqueta la funcion Lambda en un .zip listo para desplegar.
# boto3 ya viene incluido en el runtime de Lambda, asi que normalmente
# solo necesitamos empaquetar lambda_function.py. Si agregas dependencias
# en requirements.txt, este script las instala dentro del paquete.
#
# Uso:
#   ./package-lambda.sh
#
# Salida:
#   dist/logging-system.zip
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SRC_DIR="${ROOT_DIR}/src/logging-system"
DIST_DIR="${ROOT_DIR}/dist"
BUILD_DIR="${ROOT_DIR}/build"
ZIP_PATH="${DIST_DIR}/logging-system.zip"

rm -rf "$BUILD_DIR" "$ZIP_PATH"
mkdir -p "$BUILD_DIR" "$DIST_DIR"

# Instala dependencias solo si requirements.txt tiene contenido real
if [[ -s "${SRC_DIR}/requirements.txt" ]] && grep -qvE '^\s*(#.*)?$' "${SRC_DIR}/requirements.txt"; then
  echo "Instalando dependencias de requirements.txt..."
  pip install -r "${SRC_DIR}/requirements.txt" --target "$BUILD_DIR" --quiet
else
  echo "Sin dependencias externas (boto3 ya viene en el runtime de Lambda)."
fi

cp "${SRC_DIR}/lambda_function.py" "$BUILD_DIR/"

( cd "$BUILD_DIR" && zip -r -q "$ZIP_PATH" . )

echo "Paquete creado: ${ZIP_PATH}"
ls -lh "$ZIP_PATH"
