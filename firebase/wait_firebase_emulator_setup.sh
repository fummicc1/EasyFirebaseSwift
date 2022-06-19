#!/bin/sh

brew install coreutils
gtimeout 600 sh -c '
while kill -0 $(cat /tmp/firebase_emulator_pid.pid) 2>/dev/null; do
  echo "waiting firebase_emulator_setup completion."
  sleep 1
done \
  && echo "complete firebase_emulator_setup."
'