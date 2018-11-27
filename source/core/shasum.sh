#!/usr/bin/env bash

#################################
# re::shasum::compute FILE EXPECTED
#################################
#
# A shasum helper that computes a docker digest from a local file
# Sets a "computed_digest" variable with the compute digest
# Also sets a verified variable to either the null string or "verified" if the computed digest matches the second (optional) argument
regander::shasum::verify(){
  dc::require shasum
  local file="$1"
  local expected="$2"
  digest=$(shasum -a 256 "$file" 2>/dev/null)
  digest="sha256:${digest%% *}"
  if [ "$digest" != "$expected" ]; then
    dc::logger::error "Verification failed for object $file (expected: $expected - was: $digest)"
    dc::logger::debug "File was $file"
    exit "$ERROR_SHASUM_FAILED"
  fi
}

regander::shasum::compute(){
  dc::require shasum
  local file="$1"
  digest=$(shasum -a 256 "$file" 2>/dev/null)
  printf "%s" "sha256:${digest%% *}"
}
