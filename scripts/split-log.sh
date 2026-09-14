#!/usr/bin/env bash
#
# split-log.sh
# Lee un log de origen linea por linea y lo divide en batches de ~1KB.
# Cada batch se guarda como openssh-<timestamp>.log
#
# Uso:
#   ./split-log.sh [archivo_origen] [directorio_salida] [max_bytes]
#
# Ejemplo:
#   ./split-log.sh OpenSSH_2k.log batches 1024
#
set -euo pipefail

SOURCE_LOG="${1:-OpenSSH_2k.log}"
OUTPUT_DIR="${2:-batches}"
MAX_BYTES="${3:-1024}"

if [[ ! -f "$SOURCE_LOG" ]]; then
  echo "ERROR: no se encontro el archivo de origen: $SOURCE_LOG" >&2
  echo "Descargalo con:" >&2
  echo "  curl -L -o OpenSSH_2k.log https://raw.githubusercontent.com/logpai/loghub/master/OpenSSH/OpenSSH_2k.log" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

batch_num=0
current_size=0
batch_file=""

new_batch() {
  batch_num=$((batch_num + 1))
  # timestamp en epoch + contador para garantizar nombres unicos
  local ts
  ts="$(date +%s)-$(printf '%04d' "$batch_num")"
  batch_file="${OUTPUT_DIR}/openssh-${ts}.log"
  current_size=0
  : > "$batch_file"
}

new_batch

# read -r conserva las lineas tal cual; el "|| [ -n ... ]" captura la ultima linea sin \n
while IFS= read -r line || [[ -n "$line" ]]; do
  # +1 por el salto de linea
  line_size=$(( ${#line} + 1 ))

  # Si el batch actual ya tiene contenido y agregar esta linea lo pasaria
  # del limite, empezamos un batch nuevo antes de escribirla.
  if [[ "$current_size" -gt 0 && $(( current_size + line_size )) -gt "$MAX_BYTES" ]]; then
    new_batch
  fi

  printf '%s\n' "$line" >> "$batch_file"
  current_size=$(( current_size + line_size ))
done < "$SOURCE_LOG"

echo "Listo. Se generaron ${batch_num} batches en '${OUTPUT_DIR}/' (limite ~${MAX_BYTES} bytes c/u)."
ls -lh "$OUTPUT_DIR"
