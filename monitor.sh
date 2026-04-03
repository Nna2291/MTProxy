#!/bin/bash
# Live monitor for MTProxy — polls /stats every N seconds and shows key metrics.
# Usage: ./monitor.sh [interval_seconds] [stats_port]
#   defaults: interval=5, port=2398

INTERVAL=${1:-5}
PORT=${2:-2398}
URL="http://127.0.0.1:${PORT}/stats"

prev_fwd_q=0
prev_fwd_r=0
prev_tls_ok=0
prev_time=0

fmt="%-38s %s\n"

while true; do
  stats=$(curl -s --max-time 3 "$URL" 2>/dev/null)
  if [ $? -ne 0 ] || [ -z "$stats" ]; then
    echo "[$(date '+%H:%M:%S')] ERROR: cannot reach $URL"
    sleep "$INTERVAL"
    continue
  fi

  get_val() { echo "$stats" | grep "^$1	" | head -1 | cut -f2; }

  now_time=$(date +%s)
  uptime=$(get_val "uptime")
  workers=$(get_val "workers")

  conn_active=$(get_val "total_connections")
  conn_alloc=$(get_val "total_allocated_connections")
  conn_in=$(get_val "total_allocated_inbound_connections")
  conn_out=$(get_val "total_allocated_outbound_connections")
  conn_enc=$(get_val "total_encrypted_connections")
  conn_special=$(get_val "total_special_connections")
  conn_max_special=$(get_val "total_max_special_connections")

  targets_ready=$(get_val "total_ready_targets")
  targets_alloc=$(get_val "total_allocated_targets")
  targets_inactive=$(get_val "total_inactive_targets")

  fwd_q=$(get_val "tot_forwarded_queries")
  fwd_r=$(get_val "tot_forwarded_responses")
  dropped_q=$(get_val "dropped_queries")
  dropped_r=$(get_val "dropped_responses")
  expired_q=$(get_val "expired_forwarded_queries")

  tls_ok=$(get_val "tls_accepted_connections")
  tls_secret=$(get_val "tls_failed_secret")
  tls_replay=$(get_val "tls_failed_replay")
  tls_timestamp=$(get_val "tls_failed_timestamp")
  tls_parse=$(get_val "tls_failed_parse")
  tls_fallback=$(get_val "tls_proxy_fallbacks")

  buf_used=$(get_val "total_network_buffers_used_size")
  buf_alloc=$(get_val "total_network_buffers_allocated_bytes")

  mem_rss=$(get_val "vmrss_bytes")

  errors=$(get_val "mtproto_proxy_errors")
  lru_fail=$(get_val "connections_failed_lru")
  flood_fail=$(get_val "connections_failed_flood")

  qps_fwd=0
  qps_resp=0
  tls_per_sec=0
  if [ "$prev_time" -gt 0 ] && [ "$now_time" -gt "$prev_time" ]; then
    dt=$((now_time - prev_time))
    qps_fwd=$(( (${fwd_q:-0} - ${prev_fwd_q:-0}) / dt ))
    qps_resp=$(( (${fwd_r:-0} - ${prev_fwd_r:-0}) / dt ))
    tls_per_sec=$(( (${tls_ok:-0} - ${prev_tls_ok:-0}) / dt ))
  fi
  prev_fwd_q=${fwd_q:-0}
  prev_fwd_r=${fwd_r:-0}
  prev_tls_ok=${tls_ok:-0}
  prev_time=$now_time

  clear
  echo "======== MTProxy Monitor [$(date '+%H:%M:%S')] ========"
  echo ""

  printf "$fmt" "Uptime:" "${uptime}s  |  Workers: $workers"
  printf "$fmt" "Memory RSS:" "$mem_rss bytes"
  echo ""

  echo "--- Connections ---"
  printf "$fmt" "Active / Allocated:" "$conn_active / $conn_alloc"
  printf "$fmt" "Inbound / Outbound:" "$conn_in / $conn_out"
  printf "$fmt" "Encrypted:" "$conn_enc"
  printf "$fmt" "Special (cur/max):" "$conn_special / $conn_max_special"
  echo ""

  echo "--- Targets (Telegram DC) ---"
  printf "$fmt" "Ready / Allocated / Inactive:" "$targets_ready / $targets_alloc / $targets_inactive"
  echo ""

  echo "--- Throughput ---"
  printf "$fmt" "Forwarded queries (total):" "$fwd_q  (~${qps_fwd}/s)"
  printf "$fmt" "Forwarded responses (total):" "$fwd_r  (~${qps_resp}/s)"
  printf "$fmt" "Dropped queries / responses:" "$dropped_q / $dropped_r"
  printf "$fmt" "Expired queries:" "$expired_q"
  echo ""

  echo "--- TLS (fake TLS) ---"
  printf "$fmt" "Accepted (total):" "$tls_ok  (~${tls_per_sec}/s)"
  printf "$fmt" "Failed: bad secret:" "$tls_secret"
  printf "$fmt" "Failed: replay attack:" "$tls_replay"
  printf "$fmt" "Failed: bad timestamp:" "$tls_timestamp"
  printf "$fmt" "Failed: parse error:" "$tls_parse"
  printf "$fmt" "Proxy fallbacks (to real host):" "$tls_fallback"
  echo ""

  echo "--- Errors ---"
  printf "$fmt" "MTProto errors:" "$errors"
  printf "$fmt" "Failed LRU / Flood:" "$lru_fail / $flood_fail"
  echo ""

  echo "--- Buffers ---"
  printf "$fmt" "Used / Allocated:" "$buf_used / $buf_alloc bytes"

  sleep "$INTERVAL"
done
