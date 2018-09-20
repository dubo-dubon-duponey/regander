#!/usr/bin/env bash

if [ "${#@}" != 4 ]; then
  printf "%s\\n" "Usage: clone-image SOURCE_IMAGE SOURCE_TAG DESTINATION_IMAGE DESTINATION_TAG"
  exit 1
fi

SILENT="-s"

source="$1"
sourceTag="$2"
destination="$3"
destinationTag="$4"

image="$(regander $SILENT --registry=$REGISTRY manifest GET "$source" "$sourceTag")"

if [ "$?" != 0 ]; then
  echo "Failed to pull source image!"
  exit 1
fi

layers="$(echo "$image" | jq -r .layers[].digest)"
config="$(echo "$image" | jq -r .config.digest)"

printf "%s\\n" "Mounting config into new image: $config"
regander $SILENT --registry=$REGISTRY blob MOUNT "$destination" "$config" "$source"
if [ "$?" != 0 ]; then
  echo "Failed to push config!"
  exit 1
fi

for layer in $layers; do
	printf "%s\\n" "Mounting layer into new image: $layer"
	regander $SILENT --registry=$REGISTRY blob MOUNT "$destination" "$layer" "$source"
  if [ "$?" != 0 ]; then
    echo "Failed to push layer!"
    exit 1
  fi
done

printf "%s\\n" "Pushing manifest"
echo -n "$image" | regander $SILENT --registry=$REGISTRY manifest PUT "$destination" "$destinationTag"
if [ "$?" != 0 ]; then
  echo "Failed to push image!"
  exit 1
fi
