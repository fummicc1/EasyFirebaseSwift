#!/bin/sh

# stop when error
set -e
# for debug
set -x

# check whether firebase has been installed or not.
if [! type firebase >/dev/null 2>&1]; then
    # download firebase
    curl -sL https://firebase.tools | bash
fi
# setup firebase emulator only for firestore
firebase login:ci --token "$FIREBASE_TOKEN"
firebase setup:emulators:firestore
firebase emulators:start --only firestore