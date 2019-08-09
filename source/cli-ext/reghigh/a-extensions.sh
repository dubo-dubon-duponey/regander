#!/usr/bin/env bash

# Unpack a compressed file to a destination folder
re::gzip::unpack(){
  dc::require tar

  local destination="$1"
  local tarball="$2"
  local remove="$3"

  mkdir -p "$destination"
  if ! tar -C "$destination" -xzf "$tarball"; then
    dc::logger::error "Failed extracting archive $tarball"
    exit
  fi
  [ ! "$remove" ] || rm "$tarball"
}

re::gzip::pack(){
  dc::require tar

  local source="$1"
  local tarball="$2"
  local remove="$3"

  # Pack it
  if ! tar -C "$source" -cvzf "$tarball" . 2> /dev/null; then
    dc::logger::error "Failed packing the stuff into $tarball"
    exit
  fi
  #
  [ ! "$remove" ] || rm -Rf "$source"
}

reghigh::info(){
  local originImage="$1"
  local originReference="$2"
  local size=0
  local subsize=0
  local item
  local subimage
  local subitem

  if ! image=$(regander::manifest::GET "$originImage" "$originReference"); then
    dc::logger::error "Failed to pull source image $originImage $originReference"
    exit 1
  fi

#  printf "%s" "$image"

  dc::output::h1 "$originImage:$originReference"

  case $(printf "%s" "$image" | jq -rc .mediaType) in
  $MIME_V2_MANIFEST|$MIME_OCI_MANIFEST)
    dc::output::bullet "Image type: single manifest"
    dc::output::bullet "Number of blobs: $(printf "%s" "$image" | jq -rc '.layers | length')"

    for item in $(printf "%s" "$image" | jq -rc .layers[]); do
      size=$(( size + $(printf "%s" "$item" | jq -rc '.size' ) ))
    done
    size=$(( size + $(printf "%s" "$image" | jq -rc '.config.size') ))

    dc::output::bullet "Image size: $(printf "%s\n" "$size/1024/1024" | bc) MB ($size octets)"
    ;;
  $MIME_OCI_LIST|$MIME_V2_LIST)
    size="$(printf "%s" "$image" | wc -c)"

    dc::output::bullet "Image type: image list"
    dc::output::bullet "Number of sub images: $(printf "%s" "$image" | jq -rc '.manifests | length')"

    for item in $(printf "%s" "$image" | jq -rc .manifests[]); do
      subref="$(printf "%s" "$item" | jq -rc '.digest')"
      subsize="$(printf "%s" "$item" | jq -rc '.size')"
      subimage="$(regander::manifest::GET "$originImage" "$subref")"
      dc::output::h2 "$(printf "%s" "$item" | jq -rc '.platform.architecture + " - " + .platform.os + " - " + .platform.variant')"
      dc::output::bullet "Number of blobs: $(printf "%s" "$subimage" | jq -rc '.layers | length')"
      for subitem in $(printf "%s" "$subimage" | jq -rc .layers[]); do
        subsize=$(( subsize + $(printf "%s" "$subitem" | jq -rc '.size' ) ))
      done
      subsize=$(( subsize + $(printf "%s" "$subimage" | jq -rc '.config.size') ))
      dc::output::bullet "Image size: $(printf "%s\n" "$subsize/1024/1024" | bc) MB ($subsize octets)"
      size=$(( size + subsize ))
    done

    dc::output::rule
    dc::output::break
    dc::output::break
    dc::output::text "Total size: $(printf "%s\n" "$size/1024/1024" | bc) MB ($size octets)"
    dc::output::break
    ;;
  *)
    dc::logger::error "Unsupported manifest type: $image"
    ;;
  esac
}

reghigh::download(){
  local originImage="$1"
  local originReference="$2"
  local destinationFolder="$3"

  local image

  dc::fs::isdir "$destinationFolder" writable create

  # Get the root manifest
  if ! image=$(regander::manifest::GET "$originImage" "$originReference" | tee "$destinationFolder/manifest.json"); then
    dc::logger::error "Failed to download manifest!"
    exit 1
  fi

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
        re::gzip::unpack "$destinationFolder/$x" "$destinationFolder/$x.tar.gz" cleanup
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
    dc::logger::error "Unsupported manifest type: $image"
    exit 1
    ;;
  esac
}

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
    dc::logger::error "Unsupported manifest type: $image"
    exit 1
    ;;
  esac

  dc::logger::info "Now, push the manifest itself, whatever it is"
  if ! regander::manifest::PUT "$destinationImage" "$destinationTag" < <(printf "%s" "$image"); then
    dc::logger::error "Failed to create image"
    exit 1
  fi
}

# XXX regander should support --file for upload (defaulting to /dev/stdin)
_parallelUpload(){
  digestList="$1"
  printf "%s" "$digestList" | xargs -n 1 -P 4 ./bin/regander "$destinationImage" "$MIME_V2_LAYER"





  launch backgroundprocess &
PROC_ID=$!

while kill -0 "$PROC_ID" >/dev/null 2>&1; do
    echo "PROCESS IS RUNNING"
done
echo "PROCESS TERMINATED"
exit 0
}

# Hub does not support OCI yet - for now, force push just docker mime-type images
_uploadSingleImage(){
  local destinationImage="$1"
  local destinationReference="${2:-latest}"
  local originFolder="$3"

  # First, consider local, numbered tarballs
  local x
  x=1
  while [ -f "$originFolder/$x.tar.gz" ]; do
    # Upload it
    # if ! layerData=$(regander::blob::PUT "$destinationImage" "$MIME_OCI_GZLAYER" < "$originFolder/$x.tar.gz"); then
    if ! layerData=$(regander::blob::PUT "$destinationImage" "$MIME_V2_LAYER" < "$originFolder/$x.tar.gz"); then
      dc::logger::error "Failed to upload layer $originFolder/$x.tar.gz"
      exit 1
    fi
    layers+=("$layerData")
    x=$(( x + 1 ))
  done

  # Now, treat every folder as a subsequent layer
  for layer in "$originFolder"/*; do
    if [ -d "$layer" ]; then
      re::gzip::pack "$layer" "$layer.tar.gz"

      # Upload it
      if ! layerData=$(regander::blob::PUT "$destinationImage" "$MIME_OCI_GZLAYER" < "$layer.tar.gz"); then
        rm "$layer.tar.gz"
        dc::logger::error "Failed to upload layer $layer.tar.gz"
        exit 1
      fi
      rm "$layer.tar.gz"
      layers+=("$layerData")
    fi
  done

  # Now, push the config
  # if ! config=$(regander::blob::PUT "$destinationImage" "$MIME_OCI_CONFIG" < "$originFolder/config.json"); then
  if ! config=$(regander::blob::PUT "$destinationImage" "$MIME_V2_CONFIG" < "$originFolder/config.json"); then
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
  }' "$MIME_V2_MANIFEST" "$config" "[$partake]" | jq . | tee "$originFolder/manifest.json" ); then
#  }' "$MIME_OCI_MANIFEST" "$config" "[$partake]" | jq . | tee "$originFolder/manifest.json" ); then
    dc::logger::error "Failed to upload config final image"
    exit 1
  fi
}

reghigh::upload(){
  local destinationImage="$1"
  local destinationReference="${2:-latest}"
  local originFolder="$3"

  local config
  local object
  local layers=()
  local layerData

  # Pick-up a possible manifest list
  local islist
  local result
  local images=""

  # XXX abusing the protocol somewhat: force a preflight request (and drop the id on the floor), so we get the appropriate auth token for all subsequent requests and avoid useless auth round-trips in child processes
  _regander::client "$destinationImage/blobs/uploads/" POST ""

  for object in "$originFolder"/*; do
    if [ -d "$object" ]; then
      local subject
      subject="$(basename "$object")"
      local arch=${subject%%-*}
      subject=${subject#*-}
      local os=${subject%%-*}
      subject=${subject#*-}
#      local variant=${subject%%-*}
      # Splitting means we are dealing with a multi-arch image
      if [ "$arch" != "$os" ]; then
        # upload sub-folder as normal image, using the host triplet as a temp tag
        result=$(_uploadSingleImage "$destinationImage" "${arch}-${os}-${subject}" "$object")
        [ ! "$images" ] || images="$images,"

        images="$images$(printf "%s" "$result" | jq -c '.digest' | jq  --arg size "$(printf "%s" "$result" | jq -rc '.size')" \
    --arg type "$MIME_V2_MANIFEST" \
    --arg arch "$arch" \
    --arg os "$os" \
    --arg variant "$subject" \
    --arg digest "$digest" \
    -r '      {
         "mediaType": $type,
         "size": $size,
         "digest": .,
         "platform": {
            "architecture": $arch,
            "os": $os,
            "variant": $variant
         }
      }')"

        islist=true
      fi
    fi
  done

  if [ "$islist" ]; then
      # Upload the list itself, then exit
    if ! regander::manifest::PUT "$destinationImage" "$destinationReference" < <(printf "%s" "$images" | jq --arg type "$MIME_V2_LIST" -r '      {
     "schemaVersion": 2,
     "mediaType": $type,
     "manifests": [.]
  }' | tee "$originFolder/manifest.json" ); then
      dc::logger::error "Failed to upload manifest list"
      exit 1
    fi

    return
  fi

  # Not a list - it's a regular image
  _uploadSingleImage "$destinationImage" "$destinationReference" "$originFolder"

}
