#!/usr/bin/env bash

set -euo pipefail
export LC_ALL=C

usage() {
  printf 'Usage: %s [explain]\n' "${0##*/}" >&2
}

if [[ $# -gt 1 || ( $# -eq 1 && $1 != explain ) ]]; then
  usage
  exit 2
fi

read_cpu_counters() {
  awk '/^cpu / {
    total = 0
    for (field = 2; field <= 9; field++) total += $field
    print total, $5 + $6
    exit
  }' /proc/stat
}

read -r total_before idle_before < <(read_cpu_counters)
sleep 1
read -r total_after idle_after < <(read_cpu_counters)

cpu_usage=$(awk -v total_before="$total_before" -v idle_before="$idle_before" \
  -v total_after="$total_after" -v idle_after="$idle_after" 'BEGIN {
    total_delta = total_after - total_before
    idle_delta = idle_after - idle_before
    if (total_delta <= 0) {
      print "0.0"
    } else {
      printf "%.1f", 100 * (total_delta - idle_delta) / total_delta
    }
  }')

memory_usage=$(awk '
  /^MemTotal:/ { total = $2 }
  /^MemAvailable:/ { available = $2 }
  END {
    if (total <= 0) exit 1
    printf "%.1f", 100 * (total - available) / total
  }
' /proc/meminfo)

disk_usage=$(df -P / | awk 'NR == 2 { gsub(/%/, "", $5); print $5 }')

is_at_or_above_threshold() {
  awk -v usage="$1" 'BEGIN { exit !(usage >= 60) }'
}

unhealthy=0
reasons=()
for metric in "CPU:$cpu_usage" "Memory:$memory_usage" "Disk:$disk_usage"; do
  name=${metric%%:*}
  value=${metric#*:}
  if is_at_or_above_threshold "$value"; then
    unhealthy=1
    reasons+=("$name usage is ${value}%, at or above the 60% limit.")
  fi
done

if (( unhealthy )); then
  status='Not healthy'
else
  status='Healthy'
fi

if [[ ${1:-} == explain ]]; then
  printf 'CPU usage: %s%%\nMemory usage: %s%%\nDisk usage (/): %s%%\n' \
    "$cpu_usage" "$memory_usage" "$disk_usage"
  printf 'Health status: %s\n' "$status"
  if (( unhealthy )); then
    printf 'Reason: %s\n' "${reasons[*]}"
  else
    printf 'Reason: CPU, memory, and disk usage are all below 60%%.\n'
  fi
else
  printf '%s\n' "$status"
fi