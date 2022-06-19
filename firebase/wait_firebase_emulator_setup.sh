#!/bin/sh

timeout 600 bash -c '
while kill -0 $(cat /tmp/firebase_emulator_pid.pid) 2>/dev/null; do
  echo "waiting firebase_emulator_setup completion."
  sleep 1
done \
  && echo "complete firebase_emulator_setup."
'