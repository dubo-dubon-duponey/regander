#!/usr/bin/env bash

source=$1
sourceTag=$2
destination=$3
destinationTag=$4

image=$(regander -s manifest GET $source $sourceTag)
layers=$(echo $image | jq -r .layers[].digest)
config=$(echo $image | jq -r .config.digest)

echo Mounting config into new image: $config
regander -s blob MOUNT $destination $config $source

for layer in $layers; do
	echo Mounting layer into new image: $layer
	regander -s blob MOUNT $destination $layer $source
done

echo Pushing manifest
echo $image | regander -s manifest PUT $destination $destinationTag
