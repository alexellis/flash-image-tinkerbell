#!/bin/bash

echo "Starting deployment"

source functions.sh && init
set -o nounset

BASEURL="http://$MIRROR_HOST/misc/osie/current"
# assetdir=/tmp/assets
# mkdir $assetdir

curl -s "$BASEURL/image.img.tgz" --output - |tar -xzvf - > /dev/sda

# wget "$BASEURL/image.img.tgz" -P $assetdir
# cd $assetdir

# tar -xvf image.img.tgz
# dd if=./image.img of=/dev/sda
