#!/usr/bin/env bash

readonly CLI_VERSION="0.0.1"
readonly CLI_LICENSE="MIT License"
readonly CLI_DESC="docker registry shell script client"
readonly CLI_USAGE="[-s] [--insecure] [--registry=https://registry-1.docker.io] (clone|download|upload) [args]"

# Boot
dc::commander::initialize "" ""
dc::commander::declare::flag registry "^http(s)?://.+$" "optional" ""
dc::commander::declare::arg 1 "^clone|download|upload$" "" "command" "what to do"
dc::commander::boot

# Requirements
dc::require jq

# Build the registry url, possibly honoring the --registry variable
readonly REGANDER_REGISTRY="${DC_ARGV_REGISTRY:-${REGANDER_DEFAULT_REGISTRY}}/v2"

# Build the UA string
readonly REGANDER_UA="${CLI_NAME:-${DC_CLI_NAME}}/${CLI_VERSION:-${DC_CLI_VERSION}} dubocore/${DC_VERSION}-${DC_REVISION} (bash ${DC_DEPENDENCIES_V_BASH}; jq ${DC_DEPENDENCIES_V_JQ}; $(uname -mrs))"

# Map credentials to the internal variable
export REGANDER_USERNAME="$REGISTRY_USERNAME"
export REGANDER_PASSWORD="$REGISTRY_PASSWORD"

# Set accept headers
REGANDER_ACCEPT=(
  "$MIME_V2_MANIFEST"
  "$MIME_V2_LIST"
  "$MIME_OCI_MANIFEST"
  "$MIME_OCI_LIST"
)

export REGANDER_ACCEPT

# Preflight authentication
regander::version::GET > /dev/null

# Call the corresponding method
if ! reghigh::"$(echo "$1" | tr '[:upper:]' '[:lower:]')" "$2" "$3" "$4" "$5"; then
  dc::logger::error "The requested method ($1) doesn't exist or failed."
  exit "$ERROR_ARGUMENT_INVALID"
fi
