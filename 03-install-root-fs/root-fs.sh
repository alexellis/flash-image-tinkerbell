#!/bin/sh

echo "Starting deployment"

#source functions.sh && init
set -o nounset

# assetdir=/tmp/assets
# mkdir $assetdir

BASEURL="http://$MIRROR_HOST/misc/osie/current"
curl -s "$BASEURL/image.img" --output - > /dev/sda

# wget "$BASEURL/image.img.tgz" -P $assetdir
# cd $assetdir

# tar -xvf image.img.tgz
# dd if=./image.img of=/dev/sda
