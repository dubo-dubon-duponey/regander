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

if ! image="$(regander "$SILENT" --registry="$REGISTRY" manifest GET "$source" "$sourceTag")"; then
  echo "Failed to pull source image!"
  exit 1
fi

layers="$(echo "$image" | jq -r .layers[].digest)"
config="$(echo "$image" | jq -r .config.digest)"

printf "%s\\n" "Mounting config into new image: $config"
if ! regander $SILENT --registry="$REGISTRY" blob MOUNT "$destination" "$config" "$source"; then
  echo "Failed to push config!"
  exit 1
fi

for layer in $layers; do
	printf "%s\\n" "Mounting layer into new image: $layer"
	if ! regander $SILENT --registry="$REGISTRY" blob MOUNT "$destination" "$layer" "$source"; then
    echo "Failed to push layer!"
    exit 1
  fi
done

printf "%s\\n" "Pushing manifest"
if ! printf "%s" "$image" | regander "$SILENT" --registry="$REGISTRY" manifest PUT "$destination" "$destinationTag"; then
  echo "Failed to push image!"
  exit 1
fi
