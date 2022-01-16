#!/bin/sh

# check whether npm has been installed or not.
if [! type nodebrew >/dev/null 2>&1]; then
    brew install nodebrew
    nodebrew setup
    nodebrew install-binary v16.13.1
    echo 'export PATH=$HOME/.nodebrew/current/bin:$PATH' >> ~/.zprofile
fi
nodebrew use v16.13.1

# check whether firebase has been installed or not.
if [! type nodebrew >/dev/null 2>&1]; then
    npm install -g firebase-tools
fi
firebase setup:emulators:firestore
firebase emulators:start --only firestore