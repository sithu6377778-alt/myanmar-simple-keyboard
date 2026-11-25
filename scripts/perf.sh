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

echo "==> Keyboard process sitting idle for 20 s"
"$EXE" > /dev/null 2>&1 &
PID=$!
sleep 20
if ps -p "$PID" > /dev/null; then
  ps -o %cpu=,rss=,time= -p "$PID" | awk '{printf "cpu now: %s%%   memory: %.1f MB   total cpu time used in 20 s: %s\n", $1, $2/1024, $3}'
  kill "$PID"
else
  echo "(the keyboard process exited when started outside the input system)"
fi
