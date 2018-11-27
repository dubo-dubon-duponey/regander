#!/usr/bin/env bash

readonly CLI_VERSION="0.0.1"
readonly CLI_LICENSE="MIT License"
readonly CLI_DESC="docker registry shell script client"
readonly CLI_USAGE="[-s] [--insecure] [--downgrade] [--disable-verification] [--registry=https://registry-1.docker.io] endpoint METHOD [name] [reference] [source]"

# Init
dc::commander::initialize "" ""
# Validate arguments
dc::commander::declare::flag downgrade "^$" "optional" ""
dc::commander::declare::flag disable-verification "^$" "optional" ""
dc::commander::declare::flag registry "^http(s)?://.+$" "optional" ""
dc::commander::declare::arg 1 "^blob|manifest|tags|catalog|version$" "" "endpoint" "what to hit"
dc::commander::declare::arg 2 "^HEAD|GET|PUT|DELETE|MOUNT|POST$" "" "method" "method to use"
dc::commander::declare::arg 3 "$GRAMMAR_NAME" "optional" "name" "image name, like: library/nginx"
dc::commander::declare::arg 4 "$GRAMMAR_TAG_DIGEST" "optional" "reference" "tag name or digest"
dc::commander::declare::arg 5 "$GRAMMAR_NAME" "optional" "source" "when blob mounting, origin image name"
# Boot
dc::commander::boot

# Requirements
dc::require jq

# Further argument validation
if [ ${#3} -ge 256 ]; then
  dc::logger::error "Image name $3 is too long"
  exit "$ERROR_ARGUMENT_INVALID"
fi

if [ ${#5} -ge 256 ]; then
  dc::logger::error "Source image name $5 is too long"
  exit "$ERROR_ARGUMENT_INVALID"
fi


# Build the registry url, possibly honoring the --registry variable
readonly REGANDER_REGISTRY="${DC_ARGV_REGISTRY:-${REGANDER_DEFAULT_REGISTRY}}/v2"

# Build the UA string
# -${DC_BUILD_DATE} <- too much noise
readonly REGANDER_UA="${CLI_NAME:-${DC_CLI_NAME}}/${CLI_VERSION:-${DC_CLI_VERSION}} dubocore/${DC_VERSION}-${DC_REVISION} (bash ${DC_DEPENDENCIES_V_BASH}; jq ${DC_DEPENDENCIES_V_JQ}; $(uname -mrs))"

# Map credentials to the internal variable
export REGANDER_USERNAME="$REGISTRY_USERNAME"
export REGANDER_PASSWORD="$REGISTRY_PASSWORD"

# If --downgrade is passed, change the accept header
if [ "${DC_ARGE_DOWNGRADE}" ]; then
  REGANDER_ACCEPT=(
    "$MIME_V1_MANIFEST"
    "$MIME_V1_MANIFEST_JSON"
    "$MIME_V1_MANIFEST_SIGNED"
  )
else
  REGANDER_ACCEPT=(
    "$MIME_V2_MANIFEST"
    "$MIME_V2_LIST"
    "$MIME_OCI_MANIFEST"
    "$MIME_OCI_LIST"
  )
fi

export REGANDER_ACCEPT

export REGANDER_NO_VERIFY=${DC_ARGE_DISABLE_VERIFICATION}

# Call the corresponding method
if ! regander::"$(echo "$1" | tr '[:upper:]' '[:lower:]')"::"$(echo "$2" | tr '[:lower:]' '[:upper:]')" "$3" "$4" "$5"; then
  dc::logger::error "The requested endpoint ($1) and method ($2) doesn't exist in the registry specification or is not supported by regander."
  exit "$ERROR_ARGUMENT_INVALID"
fi
