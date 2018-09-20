#!/usr/bin/env bash

#####################################
# High-level registry API
#####################################

regander::version::GET(){
  # XXX technically, the version should be outputed (if present) even when authentication fails, while this method makes it mandatory to successfully authenticate
  _regander::client "" GET ""

  if [ "$DC_HTTP_HEADER_DOCKER_DISTRIBUTION_API_VERSION" != "registry/2.0" ]; then
    dc::logger::error "This server doesn't support the Registry API (expected version header was: \"$DC_HTTP_HEADER_DOCKER_DISTRIBUTION_API_VERSION)\""
    exit "$ERROR_SERVER_NOT_WHAT_YOU_THINK"
  fi

  dc::logger::info "-------------" "GET version successful: \"$DC_HTTP_HEADER_DOCKER_DISTRIBUTION_API_VERSION\""
  dc::logger::debug "$(jq '.' "$DC_HTTP_BODY" 2>/dev/null || cat "$DC_HTTP_BODY")"

  dc::output::json "\"$DC_HTTP_HEADER_DOCKER_DISTRIBUTION_API_VERSION\""
}

regander::catalog::GET() {
  _regander::client "_catalog" GET ""

  dc::logger::info "-------------" "GET catalog successful"
  dc::logger::debug "$(jq '.' "$DC_HTTP_BODY" 2>/dev/null || cat "$DC_HTTP_BODY")"

  jq '.' "$DC_HTTP_BODY"
}

regander::tags::GET() {
  local name="$1"
  registry::grammar::name "$name"

  _regander::client "$name/tags/list" GET ""

  dc::logger::info "-------------" "GET tagslist successful"
  dc::logger::debug "$(jq '.' "$DC_HTTP_BODY" 2>/dev/null || cat "$DC_HTTP_BODY")"

  jq '.' "$DC_HTTP_BODY"
}

regander::manifest::HEAD() {
  local name="$1"
  local ref="${2:-latest}" # Tag or digest
  registry::grammar::name "$name"
  registry::grammar::tagdigest "$ref"

  _regander::client "$name/manifests/$ref" HEAD ""

  dc::logger::info "HEAD manifest $name:$ref:"
  dc::logger::info " * Has a length of: $DC_HTTP_HEADER_CONTENT_LENGTH bytes"
  dc::logger::info " * Is of content-type: $DC_HTTP_HEADER_CONTENT_TYPE"
  dc::logger::info " * Has digest: $DC_HTTP_HEADER_DOCKER_CONTENT_DIGEST"

  dc::output::json "{\"type\": \"$DC_HTTP_HEADER_CONTENT_TYPE\", \"length\": \"$DC_HTTP_HEADER_CONTENT_LENGTH\", \"digest\": \"$DC_HTTP_HEADER_DOCKER_CONTENT_DIGEST\"}"
}

regander::manifest::GET() {
  local name=$1
  local ref=${2:-latest} # Tag or digest
  registry::grammar::name "$name"
  registry::grammar::tagdigest "$ref"

  _regander::client "$name/manifests/$ref" GET ""

  dc::logger::info "GET manifest $name:$ref:"
  dc::logger::info " * Has a length of: $DC_HTTP_HEADER_CONTENT_LENGTH bytes"
  dc::logger::info " * Is of content-type: $DC_HTTP_HEADER_CONTENT_TYPE"
  dc::logger::info " * Has digest: $DC_HTTP_HEADER_DOCKER_CONTENT_DIGEST"

  dc::logger::debug "$(jq '.' "$DC_HTTP_BODY" 2>/dev/null || cat "$DC_HTTP_BODY")"

  # Digest verification
  [ "$REGANDER_NO_VERIFY" ] || regander::shasum::verify "$DC_HTTP_BODY" "$DC_HTTP_HEADER_DOCKER_CONTENT_DIGEST"

  # Return the body EXACTLY as-is
  cat "$DC_HTTP_BODY"
}

regander::manifest::PUT() {
  local name="$1"
  local ref="${2:-latest}"
  registry::grammar::name "$name"
  registry::grammar::tagdigest "$ref"

  if [ -t 0 ]; then
    dc::logger::warning "Type your manifest below, then press enter, then CTRL+D to send it"
  fi

  # XXX Should payload be left untouched?
  # TODO schema validation?
  local payload

  if ! payload="$(jq -c -j . 2>/dev/null < /dev/stdin)" || [ ! "$payload" ]; then
    dc::logger::error "The provided payload is not valid json... not sending. check your input!"
    exit "$ERROR_REGISTRY_MALFORMED"
  fi
  dc::logger::debug "Gonna post this: $payload"

  local mime
  mime="$(echo "$payload" | jq -rc .mediaType 2>/dev/null)"
  # No embedded mime-type means that may be a v1 thingie
  if [ ! "$mime" ]; then
    mime=$MIME_MANIFEST_V1
  fi
  # XXX shaky - a mime type that would partially match a substring would pass
  if [[ "${REGANDER_ACCEPT[*]}" != *"$mime"* ]]; then
    echo "${REGANDER_ACCEPT[*]}"
    dc::logger::error "Mime type $mime is not recognized as a valid type."
    exit "$ERROR_ARGUMENT_INVALID"
  fi

  local shasum
  shasum=$(regander::shasum::compute /dev/stdin < <(printf "%s" "$payload"))

  dc::logger::debug "Shasum for content is $shasum"

  _regander::client "$name/manifests/$ref" PUT "$payload" "Content-type: $mime"

  if [ "$DC_HTTP_STATUS" != "201" ]; then
    dc::logger::error "Houston? Allo?"
    dc::http::dump::headers
    dc::http::dump::body
    exit "$ERROR_REGISTRY_UNKNOWN"
  fi

  dc::logger::info "Manifest succesfully uploaded"
  dc::logger::info " * Location: $DC_HTTP_HEADER_LOCATION"
  dc::logger::info " * Digest: $DC_HTTP_HEADER_DOCKER_CONTENT_DIGEST"

  dc::output::json "{\"location\": \"$DC_HTTP_HEADER_LOCATION\", \"digest:\": \"$DC_HTTP_HEADER_DOCKER_CONTENT_DIGEST\"}"
}

regander::manifest::DELETE() {
  local name="$1"
  local ref="${2:-latest}"
  registry::grammar::name "$name"
  registry::grammar::tagdigest "$ref"

  _regander::client "$name/manifests/$ref" DELETE ""

  if [ "$DC_HTTP_STATUS" != "202" ]; then
    dc::logger::error "Something went sideways"
    dc::http::dump::headers
    dc::http::dump::body
    exit "$ERROR_REGISTRY_UNKNOWN"
  fi
}

regander::blob::HEAD() {
  local name="$1"
  local ref="$2" # digest
  registry::grammar::name "$name"
  registry::grammar::digest "$ref"

  _regander::client "$name/blobs/$ref" HEAD ""

  dc::logger::info "HEAD blob $name:$ref:"
  dc::logger::info " * Has a length of: $DC_HTTP_HEADER_CONTENT_LENGTH bytes"
  dc::logger::info " * Is of content-type: $DC_HTTP_HEADER_CONTENT_TYPE"
  local finally="$name/blobs/$ref"
  if [ -n "$DC_HTTP_REDIRECTED" ]; then
    finally=$DC_HTTP_REDIRECTED
  fi
  if [ "$_DC_HTTP_REDACT" ]; then
    dc::logger::info " * Final location: REDACTED" # $finally
  else
    # Careful, this is possibly leaking a valid signed token to access private content
    dc::logger::info " * Final location: $finally"
  fi
  dc::output::json "{\"type\": \"$DC_HTTP_HEADER_CONTENT_TYPE\", \"length\": \"$DC_HTTP_HEADER_CONTENT_LENGTH\", \"location\": \"$finally\"}"
}

regander::blob::GET() {
  local name="$1"
  local ref="$2" # digest
  registry::grammar::name "$name"
  registry::grammar::digest "$ref"

  _regander::client "$name/blobs/$ref" HEAD ""

  dc::logger::info "HEAD blob $name:$ref:"
  dc::logger::info " * Has a length of: $DC_HTTP_HEADER_CONTENT_LENGTH bytes"
  dc::logger::info " * Is of content-type: $DC_HTTP_HEADER_CONTENT_TYPE"

  if [ "$DC_HTTP_REDIRECTED" ]; then
    if [ "$_DC_HTTP_REDACT" ]; then
      dc::logger::info " * Final location: REDACTED" # $finally
    else
      # Careful, this is possibly leaking a valid signed token to access private content
      dc::logger::info " * Final location: $finally"
    fi
    _regander::anonymous "$DC_HTTP_REDIRECTED" "GET" ""
  else
    _regander::client "$name/blobs/$ref" "GET" ""
  fi

  dc::logger::debug "About to verify shasum"
  [ "$REGANDER_NO_VERIFY" ] || regander::shasum::verify "$DC_HTTP_BODY" "$ref"
  dc::logger::debug "Verification done"
  # echo "$DC_HTTP_BODY"
  dc::logger::debug "About to cat $DC_HTTP_BODY"
  cat "$DC_HTTP_BODY"
  # dc::logger::debug "Done catting"
}

regander::blob::MOUNT() {
  local name="$1"
  local ref="$2"
  local from="$3"

  registry::grammar::name "$name"
  registry::grammar::digest "$ref"
  registry::grammar::name "$from"

  _regander::client "$name/blobs/uploads/?mount=$ref&from=$from" POST ""

  if [ "$DC_HTTP_STATUS" == "405" ]; then
    dc::logger::error "This registry of yours does not support blob mounts. Maybe it's a cache? Or a very old dog?"
    dc::http::dump::headers
    dc::http::dump::body
    exit "$ERROR_REGISTRY_COUGH"
  elif [ "$DC_HTTP_STATUS" != "201" ]; then
    dc::logger::error "Errr... errr... err..."
    dc::http::dump::headers
    dc::http::dump::body
    exit "$ERROR_REGISTRY_UNKNOWN"
  fi
  dc::logger::info "Mount blob $ref from $from into $name"
  dc::logger::info " * Location: $DC_HTTP_HEADER_LOCATION"
  dc::logger::info " * Digest: $DC_HTTP_HEADER_DOCKER_CONTENT_DIGEST"
  dc::logger::info " * Length: $DC_HTTP_HEADER_CONTENT_LENGTH"
  dc::output::json "{\"location\": \"$DC_HTTP_HEADER_LOCATION\", \"length\": \"$DC_HTTP_HEADER_CONTENT_LENGTH\", \"digest:\": \"$DC_HTTP_HEADER_DOCKER_CONTENT_DIGEST\"}"
}

regander::blob::DELETE() {
  local name="$1"
  local ref="$2" # digest DELETE /v2/<name>/blobs/<digest>
  registry::grammar::name "$name"
  registry::grammar::digest "$ref"

  _regander::client "$name/blobs/$ref" DELETE ""

  if [ "$DC_HTTP_STATUS" != "202" ]; then
    dc::logger::error "Something went sideways"
    dc::http::dump::headers
    dc::http::dump::body
    exit "$ERROR_REGISTRY_UNKNOWN"
  fi
}

regander::blob::PUT() {
  local name=$1
  local ref=$2
  registry::grammar::name "$name"
  #registry::grammar::digest "$ref"

  # Get an upload id
  _regander::client "$name/blobs/uploads/" POST ""

  if [ "$DC_HTTP_STATUS" != "202" ]; then
    dc::logger::error "Something went sideways"
    dc::http::dump::headers
    dc::http::dump::body
    exit "$ERROR_REGISTRY_UNKNOWN"
  fi

  # XXX sucks - need to things clean-up also wrt curl instead of flipping out files all over the place
  tmpfile=$(mktemp -t regander::blob::PUT)
  cat /dev/stdin > "$tmpfile"

  # Now do a monolithic PUT
  local digest
  local length
  digest="$(regander::shasum::compute "$tmpfile")"
  length=$(wc -c "$tmpfile" | awk '{print $1}')

  _regander::straightwithauth "$DC_HTTP_HEADER_LOCATION&digest=$digest" PUT "$tmpfile" \
    "Content-Type: application/octet-stream" \
    "Content-Length: $length"

  if [ "$DC_HTTP_STATUS" != 201 ]; then
    dc::logger::error "Something went sideways"
    dc::http::dump::headers
    dc::http::dump::body
    exit "$ERROR_REGISTRY_UNKNOWN"
  fi
  echo "\"$DC_HTTP_HEADER_DOCKER_CONTENT_DIGEST\""
}
