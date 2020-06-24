#!/bin/bash

export UUID=$(uuidgen|tr "[:upper:]" "[:lower:]")
export MAC=08:00:27:00:00:01
cat hardware.json | envsubst  > hw1.json

echo wrote hw1.json - $UUID


