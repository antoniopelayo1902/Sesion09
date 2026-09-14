#!/usr/bin/env bash
#
# start_logging.sh
# Punto de entrada de la actividad. Sube los batches a S3 esperando N
# segundos entre cada uno, tal como pide la actividad:
#
#   ./start_logging.sh 30
#
# Es un wrapper de scripts/send-logs.sh.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/scripts/send-logs.sh" "$@"
