#!/bin/bash
# CI: measures size, launch time, typing speed, memory and idle CPU of the
# built keyboard. Does not install anything.
set -euo pipefail
cd "$(dirname "$0")/.."
APP="build/pkgroot/Library/Input Methods/MyanmarSimpleKeyboard.app"
EXE="$APP/Contents/MacOS/MyanmarSimpleKeyboard"

echo "==> Size"
echo "app bundle:        $(du -sh "$APP" | cut -f1)"
echo "executable:        $(ls -lh "$EXE" | awk '{print $5}') (Apple Silicon + Intel in one file)"
echo "installer (.pkg):  $(ls -lh build/MyanmarSimpleKeyboard-*.pkg | awk '{print $5}')"

echo "==> Launch time"
/usr/bin/time -p "$EXE" --version 2>&1 | awk '/^real/ {print "start + exit:      " $2 " s"}'

echo "==> Typing benchmark"
/usr/bin/time -l "$EXE" --benchmark 2> build/time.txt
awk '/maximum resident set size/ {printf "peak memory during benchmark: %.1f MB\n", $1/1048576}' build/time.txt

echo "==> Keyboard process: startup, then sitting idle for 30 s"
cpu_seconds() { ps -o time= -p "$1" | awk -F: '{print $1 * 60 + $2}'; }
"$EXE" > /dev/null 2>&1 &
PID=$!
sleep 5
if ps -p "$PID" > /dev/null; then
  START_CPU=$(cpu_seconds "$PID")
  sleep 30
  END_CPU=$(cpu_seconds "$PID")
  ps -o rss= -p "$PID" | awk '{printf "memory (RSS):              %.1f MB\n", $1/1024}'
  echo "cpu used by startup:       ${START_CPU} s (one time)"
  awk -v a="$START_CPU" -v b="$END_CPU" 'BEGIN {printf "cpu used while idle 30 s:  %.2f s  (%.3f%% of one core)\n", b - a, (b - a) / 30 * 100}'
  kill "$PID"
else
  echo "(the keyboard process exited when started outside the input system)"
fi
