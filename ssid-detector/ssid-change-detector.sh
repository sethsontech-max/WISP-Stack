#!/bin/bash

PROMETHEUS_URL="${PROMETHEUS_URL:-http://prometheus:9090}"
CHECK_INTERVAL="${CHECK_INTERVAL:-300}"
LOOKBACK_INTERVAL="${LOOKBACK_INTERVAL:-300}"  # How many seconds to look back for comparison

log_json() {
  echo "{\"timestamp\":\"$(date -Iseconds)\",\"level\":\"$1\",\"message\":\"$2\"}"
}

# Startup log message
log_json "info" "SSID Change Detector started. Prometheus: ${PROMETHEUS_URL}, Check interval: ${CHECK_INTERVAL}s, Lookback: ${LOOKBACK_INTERVAL}s"

while true; do
  # Query current state
  current_response=$(curl -s "${PROMETHEUS_URL}/api/v1/query?query=ubntWlStatSsid")
  
  # Query state from lookback interval ago
  past_time=$(($(date +%s) - LOOKBACK_INTERVAL))
  past_response=$(curl -s "${PROMETHEUS_URL}/api/v1/query?query=ubntWlStatSsid&time=${past_time}")
  
  # Validate responses
  if ! echo "$current_response" | jq empty 2>/dev/null || ! echo "$past_response" | jq empty 2>/dev/null; then
    log_json "error" "Invalid JSON response from Prometheus"
    sleep "$CHECK_INTERVAL"
    continue
  fi
  
  # Extract current SSIDs as associative array: instance -> ssid
  current=$(echo "$current_response" | jq -r '.data.result[]? | "\(.metric.instance)|\(.metric.ubntWlStatSsid)"')
  
  # Extract past SSIDs
  past=$(echo "$past_response" | jq -r '.data.result[]? | "\(.metric.instance)|\(.metric.ubntWlStatSsid)"')
  
  if [ -z "$current" ]; then
    log_json "info" "No SSID metrics found"
    sleep "$CHECK_INTERVAL"
    continue
  fi
  
  # Compare current to past
  echo "$current" | while IFS='|' read -r instance current_ssid; do
    [ -z "$instance" ] && continue
    
    # Find what this instance had at the lookback time
    past_ssid=$(echo "$past" | grep "^${instance}|" | cut -d'|' -f2)
    
    # If we have both values and they differ, log the change
    if [ -n "$past_ssid" ] && [ "$past_ssid" != "$current_ssid" ]; then
      echo "{\"timestamp\":\"$(date -Iseconds)\",\"instance\":\"$instance\",\"old_ssid\":\"$past_ssid\",\"new_ssid\":\"$current_ssid\",\"event\":\"ssid_change\"}"
    fi
  done
  
  sleep "$CHECK_INTERVAL"
done