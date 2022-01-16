#!/bin/sh

# stop when error
set -e
# for debug
set -x

# check whether firebase has been installed or not.
if ! command -v firebase &> /dev/null
then
    # download firebase
    curl -sL https://firebase.tools | bash 
fi
# setup firebase emulator only for firestore
firebase setup:emulators:firestore
firebase emulators:start --only firestore
