#!/usr/bin/env bash

export REGISTRY_USERNAME=anonymous

source=$1
sourceTag=$2
destination=$3

verify() {
  local check=$(shasum -a 256 "$destination/$1.$2")
  check=${check%% *}
  if [ "$check" != "${1#*:}" ]; then
    echo "Verification failed!"
    echo "Expected  '${1#*:}'"
    echo "Got       '$check'"
    exit 1
  fi
}

if [ ! -d "$destination" ]; then
  mkdir -p "$destination"
fi

echo "Downloading manifest $source $sourceTag"
regander -s manifest GET $source $sourceTag > "$destination/manifest.json"

image=$(cat "$destination/manifest.json")

layers=$(echo $image | jq -r .layers[].digest)
config=$(echo $image | jq -r .config.digest)

echo "Downloading config $config"
regander -s blob GET $source $config > "$destination/$config.json"

echo "Verifying config $config"
verify $config json

for layer in $layers; do

	echo "Downloading layer $layer"
  regander -s blob GET $source $layer > "$destination/$layer.tgz"

  echo "Verifying layer $layer"
  verify $layer tgz

  echo "Unpacking layer $layer"
  mkdir -p "$destination/$layer"
  cd "$destination/$layer"
  tar -xzf ../$layer.tgz
  cd - > /dev/null
done

echo "Here is the manifest"
cat "$destination/manifest.json" | jq

echo "Here is the config"
cat "$destination/$config.json" | jq

echo "Files are here, including extracted layers: $destination"
ls "$destination"
