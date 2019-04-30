#!/usr/bin/env bash

readonly CLI_VERSION="0.0.1"
readonly CLI_LICENSE="MIT License"
readonly CLI_DESC="docker registry images manipulation client"

# Boot
dc::commander::initialize ""
dc::commander::declare::flag registry "^http(s)?://.+$" "url of the registry to communicate with" optional
dc::commander::declare::flag path "^.+$" "where a local image is located (for download and upload)" optional
dc::commander::declare::flag unpack "^$" "will unpack the layers and delete the local copies of the original tarballs" optional
dc::commander::declare::arg 1 "^download|clone|upload$" "command" "what to do (download, clone, upload)"
dc::commander::declare::arg 2 "$GRAMMAR_NAME" "image" "image name"
dc::commander::declare::arg 3 "$GRAMMAR_TAG_DIGEST" "reference" "image tag or digest" optional
dc::commander::boot

# Requirements
dc::require jq

# Build the registry url, possibly honoring the --registry variable
readonly REGANDER_REGISTRY="${DC_ARGV_REGISTRY:-${REGANDER_DEFAULT_REGISTRY}}/v2"

# Build the UA string
# -${DC_BUILD_DATE} <- too much noise
readonly REGANDER_UA="${DC_CLI_NAME}/${CLI_VERSION} dubocore/${DC_VERSION}-${DC_REVISION} (bash ${DC_DEPENDENCIES_V_BASH}; jq ${DC_DEPENDENCIES_V_JQ}; $(uname -mrs))"

# Map credentials to the internal variable
export REGANDER_USERNAME="$REGISTRY_USERNAME"
export REGANDER_PASSWORD="$REGISTRY_PASSWORD"

# Set accept headers
readonly REGANDER_ACCEPT=(
  "$MIME_V2_MANIFEST"
  "$MIME_V2_LIST"
  "$MIME_OCI_MANIFEST"
  "$MIME_OCI_LIST"
)

# Ensure we have a path on download and upload
destination=
if [ "$DC_PARGV_1" == "download" ] || [ "$DC_PARGV_1" == "upload" ]; then
  destination=${DC_ARGV_PATH:-.}
  dc::fs::isdir "$destination" writable create
fi

# Preflight authentication
regander::version::GET > /dev/null

# Call the corresponding method
if ! reghigh::"$(echo "$DC_PARGV_1" | tr '[:upper:]' '[:lower:]')" "$DC_PARGV_2" "$DC_PARGV_3" "${DC_PARGV_4:-$destination}" "$DC_PARGV_5"; then
  dc::logger::error "The requested method ($DC_PARGV_1) doesn't exist or failed."
  exit "$ERROR_ARGUMENT_INVALID"
fi
