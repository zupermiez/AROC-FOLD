#!/usr/bin/env bash
# Status of the latest detached sim benchmark (started via runs/LATEST).
#   scripts/bench_status.sh          # progress, running SR, GPU
#   scripts/bench_status.sh --stop   # stop the benchmark cleanly
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
R="$ROOT/$(cat "$ROOT/runs/LATEST")"; ID=$(basename "$R")
SUM="$ROOT/external/lehome_solution/outputs/eval_videos/$ID/eval_summary.txt"
if [[ "${1:-}" == "--stop" ]]; then
  for p in $(pgrep -f "scripts/run_eval.py.*$ID"); do kill -TERM -- -"$(ps -o pgid= "$p" | tr -d ' ')" 2>/dev/null; done
  pkill -f "scripts/serve.py --port=8000" 2>/dev/null; echo "stop signal sent"; exit 0
fi
echo "run: $ID"
pgrep -f "scripts/run_eval.py.*$ID" >/dev/null && echo "state: RUNNING" || echo "state: not running"
echo "episodes done: $(grep -cE 'Episode [0-9]+ \(' "$R/run.log") / 480   successes: $(grep -E 'Episode [0-9]+ \(' "$R/run.log" | grep -c 'Success=True')"
[[ -f "$SUM" ]] && sed -n '/^OVERALL/,/^By garment:/p' "$SUM"
grep -iE "Traceback|Error" "$R/run.log" | tail -3
nvidia-smi --query-gpu=memory.used,utilization.gpu --format=csv,noheader
