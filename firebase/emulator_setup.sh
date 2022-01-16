#!/bin/sh

# check whether firebase has been installed or not.
if [! type firebase >/dev/null 2>&1]; then
    curl -sL https://firebase.tools | bash
fi
firebase login:ci --token "$FIREBASE_TOKEN"
firebase setup:emulators:firestore
firebase emulators:start --only firestore