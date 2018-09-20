#!/usr/bin/env bash

readonly CLI_VERSION="0.0.1"
readonly CLI_LICENSE="MIT License"
readonly CLI_DESC="docker registry shell script client"
readonly CLI_USAGE="[-s] [--insecure] [--downgrade] [--disable-verification] [--registry=https://registry-1.docker.io] endpoint METHOD"

# Boot
dc::commander::init

# Requirements
dc::require::jq

# Validate arguments
dc::argv::arg::validate 1 "^blob|manifest|tags|catalog|version$" "-Ei"
dc::argv::arg::validate 2 "^HEAD|GET|PUT|DELETE|MOUNT|POST$" "-Ei"

# Build the registry url, possibly honoring the --registry variable
readonly REGANDER_REGISTRY="${DC_ARGV_REGISTRY:-${REGANDER_DEFAULT_REGISTRY}}/v2"

# Build the UA string
# -${DC_BUILD_DATE} <- too much noise
readonly REGANDER_UA="${CLI_NAME:-${DC_CLI_NAME}}/${CLI_VERSION:-${DC_CLI_VERSION}} dubocore/${DC_VERSION}-${DC_REVISION} (bash ${DC_VERSION_BASH}; jq ${DC_VERSION_JQ}; $(uname -mrs))"

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
