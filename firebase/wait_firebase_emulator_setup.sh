#!/bin/sh

if ! command -v gtimeout &> /dev/null; then
  brew install coreutils
fi

gtimeout 600 sh -c '
while :; do
  if [ ! -s "/tmp/firebase_emulator_pid.pid" ]
  then
    echo "waiting firebase_emulator_setup completion."
    sleep 3
  else
    break
  fi
done \
  && echo "complete firebase_emulator_setup."
'