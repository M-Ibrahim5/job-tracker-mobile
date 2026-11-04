#!/usr/bin/env bash
# Builds everything and runs gateway (:3000), user-service (:3001) and tracker-service (:3002).
# Configuration comes from backend/.env. Needs JDK 21 and Maven 3.9+ on PATH. Ctrl+C stops all three.
set -euo pipefail
cd "$(dirname "$0")"

mvn -q -DskipTests package

pids=()
cleanup() { kill "${pids[@]}" 2>/dev/null || true; }
trap cleanup EXIT INT TERM

for service in user-service tracker-service gateway; do
  java -jar "$service/target/$service.jar" &
  pids+=($!)
done

echo "JobTrail API on http://localhost:${PORT:-3000}/api/v1 (GET /health to check). Ctrl+C to stop."
wait
