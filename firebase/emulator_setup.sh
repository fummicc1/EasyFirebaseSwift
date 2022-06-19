#!/bin/sh

# stop when error
set -e
# for debug
set -x

# stop when pipefail
set -o pipefail

# check whether firebase has been installed or not.
if ! command -v firebase &> /dev/null
then
    # download firebase
    curl -sL https://firebase.tools | bash 
fi 
`echo which firebase` 1>&2
# setup firebase emulator only for firestore
firebase setup:emulators:firestore
firebase setup:emulators:storage
firebase emulators:start &
pid="$!"
echo "$pid" > /tmp/firebase_emulator_pid.pid
