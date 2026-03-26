#!/usr/bin/env bash
# Seed sample products into the Spring CRUD Demo API using parallel workers.
# Usage:  ./seed-products.sh [BASE_URL] [COUNT] [CONCURRENCY]
#         BASE_URL    defaults to http://localhost:8080
#         COUNT       defaults to 100
#         CONCURRENCY defaults to 20

set -uo pipefail   # -e intentionally omitted: incompatible with background jobs

BASE_URL="${1:-http://localhost:8080}"
COUNT="${2:-100}"
CONCURRENCY="${3:-20}"
URL="${BASE_URL}/api/products"

# Indexed array — works in bash 3 and 4 alike (no associative arrays needed)
CATEGORIES=(
  "Laptop|High-performance laptop|499.99|2499.99"
  "Monitor|Full-HD widescreen monitor|149.99|799.99"
  "Keyboard|Mechanical RGB keyboard|39.99|199.99"
  "Mouse|Wireless ergonomic mouse|19.99|129.99"
  "Headset|Noise-cancelling headset|49.99|349.99"
  "Webcam|4K streaming webcam|59.99|249.99"
  "SSD|NVMe solid-state drive|59.99|399.99"
  "RAM|DDR5 memory module|29.99|179.99"
  "GPU|Discrete graphics card|199.99|1299.99"
  "CPU|Multi-core desktop processor|99.99|699.99"
)
NUM_CATS=${#CATEGORIES[@]}

# Temp dir for per-request result files; cleaned up on exit
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

echo "Seeding ${COUNT} products to ${URL}  [concurrency=${CONCURRENCY}] ..."

# ------------------------------------------------------------------
# Spawn one background job per product, throttled to $CONCURRENCY.
# Each job writes a single result line to $WORK_DIR/<index>.
# ------------------------------------------------------------------
for i in $(seq 1 "$COUNT"); do
  idx=$(( (i - 1) % NUM_CATS ))
  IFS='|' read -r prefix desc min_p max_p <<< "${CATEGORIES[$idx]}"

  price=$(awk -v min="$min_p" -v max="$max_p" -v seed="$(( RANDOM * i ))" \
    'BEGIN { srand(seed); printf "%.2f", min + rand() * (max - min) }')
  qty=$(( RANDOM % 500 ))
  name="${prefix} Model-${i}"
  body=$(printf '{"name":"%s","description":"%s - unit %d","price":%s,"quantity":%d}' \
    "$name" "$desc" "$i" "$price" "$qty")

  # Background subshell — result written to a dedicated file
  (
    json_out="${WORK_DIR}/${i}.json"
    res_out="${WORK_DIR}/${i}"
    http_code=$(curl -s -o "$json_out" -w "%{http_code}" \
      -X POST "$URL" \
      -H 'Content-Type: application/json' \
      -d "$body")
    if [[ "$http_code" == "201" ]]; then
      id=$(grep -o '"id":[0-9]*' "$json_out" | head -1 | cut -d: -f2)
      printf 'OK\t%s\t%s\t%s\n' "$name" "${id:-?}" "$price" > "$res_out"
    else
      printf 'FAIL\t%s\t%s\n' "$name" "$http_code" > "$res_out"
    fi
  ) &

  # Throttle: once $CONCURRENCY jobs are active, wait for one to finish
  # before spawning the next.  'wait -n' (bash 4.3+) is preferred;
  # older bash falls back to waiting for the whole current batch.
  if (( i % CONCURRENCY == 0 )); then
    wait -n 2>/dev/null || wait
  fi
done
wait   # drain any remaining background jobs

# ------------------------------------------------------------------
# Collect and print results in original order
# ------------------------------------------------------------------
ok=0
failed=0
for i in $(seq 1 "$COUNT"); do
  res_out="${WORK_DIR}/${i}"
  [[ -f "$res_out" ]] || { echo "  [MISSING] product ${i}" >&2; (( failed++ )); continue; }

  status=$(cut -f1 "$res_out")
  if [[ "$status" == "OK" ]]; then
    (( ok++ ))
    IFS=$'\t' read -r _ pname pid pprice < "$res_out"
    echo "  [OK ${ok}] ${pname}  id=${pid}  price=${pprice}"
  else
    (( failed++ ))
    IFS=$'\t' read -r _ pname http_code _ < "$res_out"
    echo "  [FAIL] ${pname} - HTTP ${http_code}" >&2
  fi
done

echo ""
echo "Done. Created: ${ok}  Failed: ${failed}"
