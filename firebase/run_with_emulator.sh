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
    echo "Firebase CLI is not installed. Installing..."
    curl -sL https://firebase.tools | bash
fi

# setup firebase emulator only for firestore and storage
firebase setup:emulators:firestore
firebase setup:emulators:storage

# Run command with emulators
# Usage: ./run_with_emulator.sh "your command here"
# Example: ./run_with_emulator.sh "swift build && swift test"

if [ -z "$1" ]; then
    echo "Error: Please provide a command to run with emulators"
    echo "Usage: $0 \"command to run\""
    exit 1
fi

cd ..
firebase emulators:exec "$1" --project=demo-test --import=./firebase/data --export-on-exit=./firebase/data
