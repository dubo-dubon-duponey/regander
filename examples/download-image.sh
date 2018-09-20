#!/usr/bin/env bash

if [ "${#@}" != 3 ]; then
  printf "%s\\n" "Usage: download-image SOURCE_IMAGE SOURCE_TAG LOCAL_DESTINATION"
  exit 1
fi

source="$1"
sourceTag="$2"
destination="$3"

for i in $(ls sha256*); do
  # Upload blobs
done

if [ ! -d "$destination" ]; then
  mkdir -p "$destination"
fi

regander -s --registry="$REGISTRY" manifest GET "$source" "$sourceTag" > "$destination/manifest.json"

if [ "$?" != 0 ]; then
  echo "Failed to pull image!"
  exit 1
fi

image="$(cat "$destination/manifest.json")"
layers="$(echo "$image" | jq -r .layers[].digest)"
config="$(echo "$image" | jq -r .config.digest)"

printf "%s\\n" "Downloading config: $config"
regander -s --registry="$REGISTRY" blob GET "$source" "$config" > "$destination/$config.json"

if [ "$?" != 0 ]; then
  echo "Failed to download config $config!"
  exit 1
fi

for layer in $layers; do
	printf "%s\\n" "Downloading layer: $layer"
	regander -s --registry="$REGISTRY" blob GET "$source" "$layer" > "$destination/$layer.tgz"

  if [ "$?" != 0 ]; then
    echo "Failed to download layer $layer!"
    exit 1
  fi

  echo "Unpacking layer $layer"
  mkdir -p "$destination/$layer"
  cd "$destination/$layer" > /dev/null || exit 1
  tar -xzf ../$layer.tgz
  cd - > /dev/null || exit 1
done
