#!/usr/bin/env bash

if [ "${#@}" != 3 ]; then
  printf "%s\\n" "Usage: download-image SOURCE_IMAGE SOURCE_TAG LOCAL_DESTINATION"
  exit 1
fi

source="$1"
sourceTag="$2"
destination="$3"

if [ ! -d "$destination" ]; then
  mkdir -p "$destination"
fi

if regander -s --registry="$REGISTRY" manifest GET "$source" "$sourceTag" > "$destination/manifest.json"; then
  echo "Failed to download manifest!"
  exit 1
fi

image="$(cat "$destination/manifest.json")"
layers="$(echo "$image" | jq -r .layers[].digest)"
config="$(echo "$image" | jq -r .config.digest)"

printf "%s\\n" "Downloading config: $config"

if regander -s --registry="$REGISTRY" blob GET "$source" "$config" > "$destination/$config.json"; then
  echo "Failed to download config $config!"
  exit 1
fi

for layer in $layers; do
	printf "%s\\n" "Downloading layer: $layer"
	if regander -s --registry="$REGISTRY" blob GET "$source" "$layer" > "$destination/$layer.tgz"; then
    echo "Failed to download layer $layer!"
    exit 1
  fi

  echo "Unpacking layer $layer"
  mkdir -p "$destination/$layer"
  cd "$destination/$layer" > /dev/null || exit 1
  tar -xzf ../"$layer.tgz"
  cd - > /dev/null || exit 1
done
