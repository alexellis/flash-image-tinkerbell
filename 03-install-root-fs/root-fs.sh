#!/bin/bash

source functions.sh && init
set -o nounset

BASEURL="http://$MIRROR_HOST/misc/osie/current"
assetdir=/tmp/assets
mkdir $assetdir
wget "$BASEURL/image.img.tgz" -P $assetdir
cd $assetdir

tar -xvf image.img.tgz
dd if=./image.img of=/dev/sda
