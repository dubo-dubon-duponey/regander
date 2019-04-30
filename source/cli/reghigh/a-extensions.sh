#!/usr/bin/env bash

# Methods
reghigh::clone(){
  local originImage="$1"
  local originReference="$2"
  local destinationImage="$3"
  local destinationTag="$4"
  local image

  dc::logger::info "> Cloning image $originImage $originReference"
  if ! image=$(regander::manifest::GET "$originImage" "$originReference"); then
    dc::logger::error "Failed to pull source image $originImage $originReference"
    exit 1
  fi

  # Specialize based on mediaType
  case $(printf "%s" "$image" | jq -rc .mediaType) in
  $MIME_V2_MANIFEST|$MIME_OCI_MANIFEST)
    dc::logger::info ">> Regular image"
    local config
    local layer

    # It's a regular image, mount the config and layers
    config="$(printf "%s" "$image" | jq -r .config.digest)"

    dc::logger::info ">>> Mounting config $config into new image $destinationImage"
    if ! regander::blob::MOUNT "$destinationImage" "$config" "$originImage" > /dev/null; then
      dc::logger::error "Failed to mount config!"
      exit 1
    fi

    for layer in $(printf "%s" "$image" | jq -r .layers[].digest); do
      dc::logger::info ">>> Mounting layer $layer into new image $destinationImage"
      if ! regander::blob::MOUNT "$destinationImage" "$layer" "$originImage" > /dev/null; then
        dc::logger::error "Failed to mount layer!"
        exit 1
      fi
    done
    ;;
  $MIME_OCI_LIST|$MIME_V2_LIST)
    dc::logger::info "> List image"
    # It's a list, call clone on every individual image in there
    local digest
    for digest in $(printf "%s" "$image" | jq -rc .manifests[].digest); do
      dc::logger::info ">> Cloning sub-image"
      reghigh::clone "$originImage" "$digest" "$destinationImage" "$digest"
    done
    ;;
  *)
    dc::logger::error "Unsupported manifest type. Not sure what is this: $image"
    exit 1
    ;;
  esac

  dc::logger::info "Now, push the manifest itself, whatever it is"
  if ! regander::manifest::PUT "$destinationImage" "$destinationTag" < <(printf "%s" "$image"); then
    dc::logger::error "Failed to create image"
    exit 1
  fi
}

reghigh::download(){
  local originImage="$1"
  local originReference="$2"
  local destinationFolder="$3"

  # Get the root manifest
  if ! regander::manifest::GET "$originImage" "$originReference" > "$destinationFolder/manifest.json"; then
    dc::logger::error "Failed to download manifest!"
    exit 1
  fi

  local image
  image="$(cat "$destinationFolder/manifest.json")"

  # Depending on the content-type...
  case $(printf "%s" "$image" | jq -rc .mediaType) in
  # It's a girl, download the layers
  $MIME_V2_MANIFEST|$MIME_OCI_MANIFEST)
    local config
    local layer

    config="$(printf "%s" "$image" | jq -rc .config.digest)"

    dc::logger::info "Downloading config $config"
    if ! regander::blob::GET "$originImage" "$config" > "$destinationFolder/config.json"; then
      dc::logger::error "Failed to download config $config!"
      exit 1
    fi

    local x
    x=0
    for layer in $(printf "%s" "$image" | jq -rc .layers[].digest); do
      x=$(( x + 1 ))
      dc::logger::info "Downloading layer number $x ($layer)"
      if ! regander::blob::GET "$originImage" "$layer" > "$destinationFolder/$x.tar.gz"; then
        dc::logger::error "Failed to download layer $layer!"
        exit 1
      fi

      if [ "$DC_ARGE_UNPACK" ]; then
        dc::logger::info "Unpacking layer $x ($layer)"
        mkdir -p "$destinationFolder/$x"
        cd "$destinationFolder/$x" > /dev/null || exit 1
        tar -xzf ../"$x.tar.gz"
        rm ../"$x.tar.gz"
        cd - > /dev/null || exit 1
      fi
    done
    ;;
  # It's a boy, download the linked manifests
  $MIME_OCI_LIST|$MIME_V2_LIST)
    # It's a list, call clone on every individual image in there
    local item
    local dest
    for item in $(printf "%s" "$image" | jq -rc .manifests[]); do
      dc::logger::info ">> Downloading sub-image"
      dest=$(printf "%s" "$item" | jq -rc '.platform.architecture + "-" + .platform.os + "-" + .platform.variant')
      reghigh::download "$originImage" "$(printf "%s" "$item" | jq -rc .digest)" "$destinationFolder/$dest"
    done
    ;;
  # It's an alien, drop it
  *)
    dc::logger::error "Unsupported manifest type. Not sure what is this: $image"
    exit 1
    ;;
  esac

}

reghigh::upload(){
  local destinationImage="$1"
  local destinationReference="${2:-latest}"
  local originFolder="$3"
  local image
  local config
  local layer
  local layers=()
  local layerData

  # Pick-up a possible manifest list
  local islist

  for layer in "$originFolder"/*; do
    if [ -d "$layer" ]; then
      local subject
      subject="$(basename "$layer")"
      local arch=${subject%%-*}
      subject=${subject#*-}
      local os=${subject%%-*}
      subject=${subject#*-}
#      local variant=${subject%%-*}
      # Splitting means we are dealing with a multi-arch image
      if [ "$arch" != "$os" ]; then
        # upload sub-subfolders as normal images
        reghigh::upload "$layer" "$destinationImage"
        islist=true
      fi
    fi
  done

  if [ "$islist" ]; then
    # Upload the list itself, then exit
    return
  fi

  # Not a list - it's a regular image

  # First, consider local tarballs
  local x
  x=1
  while [ -f "$originFolder/$x.tar.gz" ]; do
    # Upload it
    if ! layerData=$(regander::blob::PUT "$destinationImage" "$MIME_OCI_GZLAYER" < "$originFolder/$x.tar.gz"); then
      dc::logger::error "Failed to upload layer $originFolder/$x.tar.gz"
      exit 1
    fi
    layers+=("$layerData")
    x=$(( x + 1 ))
  done

  # Now, treat every folder as a subsequent layer
  for layer in "$originFolder"/*; do
    if [ -d "$layer" ]; then
      cd "$layer" > /dev/null || exit 1
      layer="$(basename "$layer")".tar.gz
      # Pack it
      tar -cvzf "../$layer" . 2> /dev/null
      # Upload it
      if ! layerData=$(regander::blob::PUT "$destinationImage" "$MIME_OCI_GZLAYER" < "../$layer"); then
        rm "../$layer"
        dc::logger::error "Failed to upload layer $layer"
        exit 1
      fi
      rm "../$layer"
      cd - > /dev/null || exit 1
      layers+=("$layerData")
    fi
  done

  # Now, push the config
  if ! config=$(regander::blob::PUT "$destinationImage" "$MIME_OCI_CONFIG" < "$originFolder/config.json"); then
    dc::logger::error "Failed to upload config $config"
    exit 1
  fi

  local i
  local partake
  for i in "${layers[@]}"; do
    [ "$partake" ] && partake="$partake,"
    partake="$partake$i"
  done

  # Finally push the manifest itself, with the rebuilt layer list
  if ! regander::manifest::PUT "$destinationImage" "$destinationReference" < <(printf '{
     "schemaVersion": 2,
     "mediaType": "%s",
     "config": %s,
     "layers": %s
  }' "$MIME_OCI_MANIFEST" "$config" "[$partake]"); then
    dc::logger::error "Failed to upload config final image"
    exit 1
  fi
}
