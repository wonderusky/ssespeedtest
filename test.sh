#!/bin/zsh

# SSE / Direct Performance Test
#
# Usage:
#   ./test.sh
#   ./test.sh 120 300 16 mbp prisma
#   ./test.sh 120 300 16 mbp direct mbp_direct_16.csv
#   ./test.sh 120 300 16 mbp prisma mbp_prisma_16.csv "https://ash-speed.hetzner.com/100MB.bin" 300
#
# Args:
#   $1 = interval seconds, default 120
#   $2 = baseline Mbps, default 300
#   $3 = parallel streams, default 16
#   $4 = device label, default "device"
#   $5 = path label, default "path"  examples: direct, prisma, zscaler
#   $6 = log file, default "<device>_<path>_<streams>_streams.csv"
#   $7 = download URL, default Hetzner Ashburn 100MB
#   $8 = curl max-time seconds, default 300

INTERVAL="${1:-120}"
MAX_BANDWIDTH_MBPS="${2:-300}"
STREAMS="${3:-16}"
DEVICE_LABEL="${4:-device}"
PATH_LABEL="${5:-path}"
LOG_FILE="${6:-${DEVICE_LABEL}_${PATH_LABEL}_${STREAMS}_streams.csv}"
CDN_URL="${7:-https://ash-speed.hetzner.com/100MB.bin}"
CURL_MAX_TIME="${8:-300}"

SAAS_URL="https://login.salesforce.com"
PING_TARGET="zoom.us"

MIN_VALID_BYTES=1000000

# -----------------------------
# Validation
# -----------------------------

if ! [[ "$INTERVAL" =~ '^[0-9]+$' ]]; then
  echo "ERROR: Interval must be a number."
  echo "Example: ./test.sh 120 300 16 mbp prisma"
  exit 1
fi

if ! [[ "$MAX_BANDWIDTH_MBPS" =~ '^[0-9]+([.][0-9]+)?$' ]]; then
  echo "ERROR: Baseline Mbps must be a number."
  echo "Example: ./test.sh 120 300 16 mbp prisma"
  exit 1
fi

if ! [[ "$STREAMS" =~ '^[0-9]+$' ]] || [ "$STREAMS" -lt 1 ]; then
  echo "ERROR: Streams must be a positive integer."
  echo "Example: ./test.sh 120 300 16 mbp prisma"
  exit 1
fi

if ! [[ "$CURL_MAX_TIME" =~ '^[0-9]+$' ]]; then
  echo "ERROR: Curl max-time must be a number."
  echo "Example: ./test.sh 120 300 16 mbp prisma mbp_prisma.csv \"https://ash-speed.hetzner.com/100MB.bin\" 300"
  exit 1
fi

# -----------------------------
# CSV Header
# -----------------------------

if [ ! -f "$LOG_FILE" ]; then
  echo "Timestamp,Device_Label,Path_Label,Egress_IP,Download_URL,Streams_Requested,Single_HTTP,Single_Bytes,Single_Time_sec,Single_Mbps,Multi_Streams_Successful,Multi_Bytes,Multi_Time_sec,Multi_Mbps,Efficiency_%,SaaS_URL,SaaS_TTFB_sec,Ping_Target,Latency_Avg_ms,Packet_Loss_%" > "$LOG_FILE"
  echo "Created log file: $LOG_FILE"
fi

# -----------------------------
# Start
# -----------------------------

echo "Starting performance test."
echo "Device label     : $DEVICE_LABEL"
echo "Path label       : $PATH_LABEL"
echo "Interval         : ${INTERVAL} seconds"
echo "Baseline         : ${MAX_BANDWIDTH_MBPS} Mbps"
echo "Download URL     : $CDN_URL"
echo "Streams          : $STREAMS"
echo "Curl max-time    : $CURL_MAX_TIME seconds"
echo "SaaS URL         : $SAAS_URL"
echo "Ping target      : $PING_TARGET"
echo "Log file         : $LOG_FILE"
echo "Press Ctrl+C to stop."
echo "------------------------------------------------------------------------"

while true; do
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$TIMESTAMP] Running tests..."

  # -----------------------------
  # Public egress IP
  # -----------------------------

  EGRESS_IP=$(curl -s --connect-timeout 5 --max-time 10 https://ifconfig.me)
  if [ -z "$EGRESS_IP" ]; then
    EGRESS_IP="unknown"
  fi

  # -----------------------------
  # Single-stream download test
  # -----------------------------

  SINGLE_OUT=$(curl -L \
    --connect-timeout 10 \
    --max-time "$CURL_MAX_TIME" \
    -o /dev/null \
    -sS \
    -w "%{http_code},%{speed_download},%{size_download},%{time_total}" \
    "$CDN_URL" 2>/tmp/curl_single_err)

  SINGLE_EXIT=$?

  if [ "$SINGLE_EXIT" -ne 0 ]; then
    SINGLE_HTTP="curl_error_$SINGLE_EXIT"
    SINGLE_BYTES=0
    SINGLE_TIME=0
    SINGLE_MBPS=0
  else
    SINGLE_HTTP=$(echo "$SINGLE_OUT" | awk -F',' '{print $1}')
    SINGLE_BPS=$(echo "$SINGLE_OUT" | awk -F',' '{print $2}')
    SINGLE_BYTES=$(echo "$SINGLE_OUT" | awk -F',' '{print $3}')
    SINGLE_TIME=$(echo "$SINGLE_OUT" | awk -F',' '{print $4}')

    if [ "$SINGLE_HTTP" != "200" ] || [ "$SINGLE_BYTES" -lt "$MIN_VALID_BYTES" ]; then
      SINGLE_MBPS=0
    else
      SINGLE_MBPS=$(awk "BEGIN {printf \"%.2f\", ($SINGLE_BPS * 8) / 1000000}")
    fi
  fi

  # -----------------------------
  # Multi-stream download test
  # -----------------------------

  TMP_DIR=$(mktemp -d /tmp/sse_test.XXXXXX)
  START_TIME=$(python3 -c 'import time; print(time.time())')

  for i in $(seq 1 "$STREAMS"); do
    curl -L \
      --connect-timeout 10 \
      --max-time "$CURL_MAX_TIME" \
      -o /dev/null \
      -s \
      -w "%{http_code},%{size_download},%{time_total}" \
      "$CDN_URL" > "$TMP_DIR/stream_$i.out" 2>/dev/null &
  done

  wait

  END_TIME=$(python3 -c 'import time; print(time.time())')
  MULTI_TIME=$(awk "BEGIN {printf \"%.3f\", $END_TIME - $START_TIME}")

  MULTI_SUCCESS=0
  MULTI_BYTES=0

  for f in "$TMP_DIR"/stream_*.out; do
    if [ -f "$f" ]; then
      HTTP_CODE=$(awk -F',' '{print $1}' "$f")
      BYTES_DOWNLOADED=$(awk -F',' '{print $2}' "$f")

      if [ "$HTTP_CODE" = "200" ] && [ "$BYTES_DOWNLOADED" -ge "$MIN_VALID_BYTES" ]; then
        MULTI_SUCCESS=$((MULTI_SUCCESS + 1))
        MULTI_BYTES=$((MULTI_BYTES + BYTES_DOWNLOADED))
      fi
    fi
  done

  rm -rf "$TMP_DIR"

  if [ "$MULTI_SUCCESS" -eq 0 ] || [ "$MULTI_TIME" = "0.000" ]; then
    MULTI_MBPS=0
    EFFICIENCY_PCT=0
  else
    MULTI_MBPS=$(awk "BEGIN {printf \"%.2f\", ($MULTI_BYTES * 8) / ($MULTI_TIME * 1000000)}")
    EFFICIENCY_PCT=$(awk "BEGIN {printf \"%.1f\", ($MULTI_MBPS / $MAX_BANDWIDTH_MBPS) * 100}")
  fi

  # -----------------------------
  # SaaS TTFB
  # -----------------------------

  TTFB=$(curl -L \
    --connect-timeout 10 \
    --max-time 30 \
    -sS \
    -o /dev/null \
    -w "%{time_starttransfer}" \
    "$SAAS_URL" 2>/dev/null)

  if [ -z "$TTFB" ]; then
    TTFB="0"
  fi

  # -----------------------------
  # Latency and packet loss
  # -----------------------------

  PING_OUT=$(ping -c 10 "$PING_TARGET" 2>/dev/null)
  PLOSS=$(echo "$PING_OUT" | awk -F' ' '/packet loss/ {print $7}' | tr -d '%')
  LATENCY=$(echo "$PING_OUT" | awk -F'/' '/round-trip/ {print $5}')

  if [ -z "$PLOSS" ]; then
    PLOSS="100"
  fi

  if [ -z "$LATENCY" ]; then
    LATENCY="0"
  fi

  # -----------------------------
  # Write CSV
  # -----------------------------

  echo "$TIMESTAMP,$DEVICE_LABEL,$PATH_LABEL,$EGRESS_IP,$CDN_URL,$STREAMS,$SINGLE_HTTP,$SINGLE_BYTES,$SINGLE_TIME,$SINGLE_MBPS,$MULTI_SUCCESS,$MULTI_BYTES,$MULTI_TIME,$MULTI_MBPS,$EFFICIENCY_PCT,$SAAS_URL,$TTFB,$PING_TARGET,$LATENCY,$PLOSS" >> "$LOG_FILE"

  # -----------------------------
  # Console output
  # -----------------------------

  echo "  -> Device           : $DEVICE_LABEL"
  echo "  -> Path             : $PATH_LABEL"
  echo "  -> Egress IP        : $EGRESS_IP"
  echo "  -> Single Stream    : ${SINGLE_MBPS} Mbps, HTTP=$SINGLE_HTTP, Bytes=$SINGLE_BYTES, Time=${SINGLE_TIME}s"
  echo "  -> Multi Stream     : ${MULTI_MBPS} Mbps using ${MULTI_SUCCESS}/${STREAMS} successful streams"
  echo "  -> Multi Bytes      : $MULTI_BYTES"
  echo "  -> Multi Time       : ${MULTI_TIME}s"
  echo "  -> Efficiency       : ${EFFICIENCY_PCT}% of ${MAX_BANDWIDTH_MBPS} Mbps baseline"
  echo "  -> SaaS TTFB        : ${TTFB} s"
  echo "  -> Zoom Latency     : ${LATENCY} ms (Loss: ${PLOSS}%)"
  echo "Waiting $INTERVAL seconds until next run..."
  echo "------------------------------------------------------------------------"

  sleep "$INTERVAL"
done
