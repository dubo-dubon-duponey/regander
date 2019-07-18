#!/usr/bin/env bash

#####################################
# High-level registry API
#####################################

regander::version::GET(){
  # XXX Technically, the version is present even when authentication fails
  # We are blatantly cheating here and forcing a non-erroring unauthenticated request to avoid a useless round trip to the auth server
  #  _regander::client "" GET ""
  _wrapper::request "$REGANDER_REGISTRY/" "GET" ""

  # If the header does not match expectation, bail out
  if [ "$DC_HTTP_HEADER_DOCKER_DISTRIBUTION_API_VERSION" != "registry/2.0" ]; then
    dc::logger::error "This server doesn't support the Registry API v2.0" "Returned version header was: \"$DC_HTTP_HEADER_DOCKER_DISTRIBUTION_API_VERSION\""
    exit "$ERROR_SERVER_NOT_WHAT_YOU_THINK"
  fi

  # Log op name and key result
  dc::logger::info "GET version successful: \"$DC_HTTP_HEADER_DOCKER_DISTRIBUTION_API_VERSION\""
  # Debug log response body
  dc::logger::debug "$(jq '.' "$DC_HTTP_BODY" 2>/dev/null || cat "$DC_HTTP_BODY")"

  # Output the response
  dc::output::json "\"$DC_HTTP_HEADER_DOCKER_DISTRIBUTION_API_VERSION\""
}

regander::catalog::GET() {
  _regander::client "_catalog" GET ""

  # Log op name and key result
  dc::logger::info "GET catalog successful"
  # Debug log response body
  dc::logger::debug "$(jq '.' "$DC_HTTP_BODY" 2>/dev/null || cat "$DC_HTTP_BODY")"

  # Output the response body
  jq '.' "$DC_HTTP_BODY"
}

regander::tags::GET() {
  local name="$1"

  _regander::client "$name/tags/list" GET ""

  # Log op name and key result
  dc::logger::info "GET tagslist successful for image $name"
  # Debug log response body
  dc::logger::debug "$(jq '.' "$DC_HTTP_BODY" 2>/dev/null || cat "$DC_HTTP_BODY")"

  # Output the response body
  jq '.' "$DC_HTTP_BODY"
}

regander::manifest::HEAD() {
  local name="$1"
  local ref="${2:-latest}"

  _regander::client "$name/manifests/$ref" HEAD ""

  # Log op name and key result
  dc::logger::info "HEAD manifest successful for image $name:$ref"
  # Debug log key headers
  dc::logger::debug " * Has a length of: $DC_HTTP_HEADER_CONTENT_LENGTH bytes"
  dc::logger::debug " * Is of content-type: $DC_HTTP_HEADER_CONTENT_TYPE"
  dc::logger::debug " * Has digest: $DC_HTTP_HEADER_DOCKER_CONTENT_DIGEST"

  # Output key response headers
  dc::output::json "{\"type\": \"$DC_HTTP_HEADER_CONTENT_TYPE\", \"size\": \"$DC_HTTP_HEADER_CONTENT_LENGTH\", \"digest\": \"$DC_HTTP_HEADER_DOCKER_CONTENT_DIGEST\"}"
}

regander::manifest::GET() {
  local name=$1
  local ref=${2:-latest} # Tag or digest

  _regander::client "$name/manifests/$ref" GET ""

  # Log op name and key result
  dc::logger::info "GET manifest successful for image $name:$ref"
  # Debug log key headers
  dc::logger::debug " * Has a length of: $DC_HTTP_HEADER_CONTENT_LENGTH bytes"
  dc::logger::debug " * Is of content-type: $DC_HTTP_HEADER_CONTENT_TYPE"
  dc::logger::debug " * Has digest: $DC_HTTP_HEADER_DOCKER_CONTENT_DIGEST"

  # Debug log body
  dc::logger::debug "$(jq '.' "$DC_HTTP_BODY" 2>/dev/null || cat "$DC_HTTP_BODY")"

  # Verify content matches digest
  [ "$REGANDER_NO_VERIFY" ] || dc::crypto::shasum::verify "$DC_HTTP_BODY" "$DC_HTTP_HEADER_DOCKER_CONTENT_DIGEST"

  # Output the body EXACTLY as-is
  cat "$DC_HTTP_BODY"
}

regander::manifest::PUT() {
  local name="$1"
  local ref="${2:-latest}"

  if [ -t 0 ]; then
    dc::logger::warning "Type or copy / paste your manifest below, then press enter, then CTRL+D to send it"
  fi

  # TODO schema validation?
  local payload
  local raw
  local size

  raw="$(cat /dev/stdin)"
  if ! payload="$(printf "%s" "$raw" | jq -c -j . 2>/dev/null)" || [ ! "$payload" ]; then
    dc::logger::error "The provided payload is not valid json... not sending. check your input: $raw"
    exit "$ERROR_REGISTRY_MALFORMED"
  fi

  local mime
  mime="$(printf "%s" "$payload" | jq -rc .mediaType 2>/dev/null)"
  # No embedded mime-type means that may be a v1 thingie - urg
  if [ ! "$mime" ]; then
    mime=$MIME_MANIFEST_V1
  fi
  if [[ "${REGANDER_ACCEPT[*]}" != *" $mime "* ]] && [[ "${REGANDER_ACCEPT[*]}" != *" $mime" ]] && [[ "${REGANDER_ACCEPT[*]}" != "$mime "* ]]; then
    dc::logger::error "Mime type $mime is not recognized as a valid type."
    exit "$ERROR_ARGUMENT_INVALID"
  fi

  local shasum
  shasum=$(dc::crypto::shasum::compute /dev/stdin < <(printf "%s" "$raw"))

  dc::logger::info "Shasum for content is $shasum. Going to push to $name/manifests/$ref."

  _regander::client "$name/manifests/$ref" PUT "$raw" "Content-type: $mime"

  _regander::expect 201

  dc::logger::info "PUT manifest successful"
  dc::logger::debug " * Location: $DC_HTTP_HEADER_LOCATION"
  dc::logger::debug " * Digest: $DC_HTTP_HEADER_DOCKER_CONTENT_DIGEST"

  dc::output::json "{\"location\": \"$DC_HTTP_HEADER_LOCATION\", \"digest\": \"$DC_HTTP_HEADER_DOCKER_CONTENT_DIGEST\", \"size\": \"$(printf "%s" "$raw" | wc -c | awk '{print $1; }')\"}"
}

regander::manifest::DELETE() {
  local name="$1"
  local ref="${2:-latest}"

  _regander::client "$name/manifests/$ref" DELETE ""

  _regander::expect 202
}

regander::blob::HEAD() {
  # Restrict to digest
  # XXX unfortunately, this breaks when the cli is different than regander
  # dc::commander::declare::arg 4 "$GRAMMAR_DIGEST_SHA256"

  local name="$1"
  local ref="$2" # digest

  _regander::client "$name/blobs/$ref" HEAD ""

  dc::logger::info "HEAD blob successful"
  dc::logger::debug " * Has a length of: $DC_HTTP_HEADER_CONTENT_LENGTH bytes"
  dc::logger::debug " * Is of content-type: $DC_HTTP_HEADER_CONTENT_TYPE"

  local finally="$name/blobs/$ref"
  if [ "$DC_HTTP_REDIRECTED" ]; then
    finally=$DC_HTTP_REDIRECTED
  fi
  if [ "$_DC_HTTP_REDACT" ]; then
    dc::logger::debug " * Final location: REDACTED" # $finally
  else
    # Careful, this is possibly leaking a valid signed token to access private content
    dc::logger::debug " * Final location: $finally"
  fi
  dc::output::json "{\"type\": \"$DC_HTTP_HEADER_CONTENT_TYPE\", \"size\": \"$DC_HTTP_HEADER_CONTENT_LENGTH\", \"location\": \"$finally\"}"
}

regander::blob::GET() {
  # Restrict to digest
  # XXX unfortunately, this breaks when the cli is different than regander
  # dc::commander::declare::arg 4 "$GRAMMAR_DIGEST_SHA256"

  local name="$1"
  local ref="$2" # digest

  _regander::client "$name/blobs/$ref" HEAD ""

  dc::logger::info "GET blob successful"
  dc::logger::debug " * Has a length of: $DC_HTTP_HEADER_CONTENT_LENGTH bytes"
  dc::logger::debug " * Is of content-type: $DC_HTTP_HEADER_CONTENT_TYPE"

  if [ "$DC_HTTP_REDIRECTED" ]; then
    if [ "$_DC_HTTP_REDACT" ]; then
      dc::logger::debug " * Final location: REDACTED" # $finally
    else
      # Careful, this is possibly leaking a valid signed token to access private content
      dc::logger::debug " * Final location: $DC_HTTP_REDIRECTED"
    fi
    _regander::anonymous "$DC_HTTP_REDIRECTED" "GET" ""
  else
    _regander::client "$name/blobs/$ref" "GET" ""
  fi

  dc::logger::debug "About to verify shasum"
  [ "$REGANDER_NO_VERIFY" ] || dc::crypto::shasum::verify "$DC_HTTP_BODY" "$ref"
  dc::logger::debug "Verification done"
  # echo "$DC_HTTP_BODY"
  dc::logger::debug "About to cat $DC_HTTP_BODY"
  cat "$DC_HTTP_BODY"
  # dc::logger::debug "Done catting"
}

regander::blob::MOUNT() {
  # Restrict to digest
  # XXX unfortunately, this breaks when the cli is different than regander
  # dc::commander::declare::arg 4 "$GRAMMAR_DIGEST_SHA256"

  local name="$1"
  local ref="$2"
  local from="$3"

  _regander::client "$name/blobs/uploads/?mount=$ref&from=$from" POST ""

  _regander::expect 201

  dc::logger::info "MOUNT blob successful"
  dc::logger::debug " * Location: $DC_HTTP_HEADER_LOCATION"
  dc::logger::debug " * Digest: $DC_HTTP_HEADER_DOCKER_CONTENT_DIGEST"
  dc::logger::debug " * Length: $DC_HTTP_HEADER_CONTENT_LENGTH"
  dc::output::json "{\"location\": \"$DC_HTTP_HEADER_LOCATION\", \"size\": \"$DC_HTTP_HEADER_CONTENT_LENGTH\", \"digest\": \"$DC_HTTP_HEADER_DOCKER_CONTENT_DIGEST\"}"
}

regander::blob::DELETE() {
  # Restrict to digest
  # XXX unfortunately, this breaks when the cli is different than regander
  # dc::commander::declare::arg 4 "$GRAMMAR_DIGEST_SHA256"

  local name="$1"
  local ref="$2" # digest DELETE /v2/<name>/blobs/<digest>

  _regander::client "$name/blobs/$ref" DELETE ""

  _regander::expect 202
}

regander::blob::PUT() {
  # Restrict to media-type, optional
  # XXX unfortunately, this breaks when the cli is different than regander
  # dc::commander::declare::arg 4 "$GRAMMAR_LAYER_TYPE" "media-type" "media-type of the blob" optional

  local name="$1"
  local type="${2:-$MIME_OCI_GZLAYER}"

  # XXX sucks - need to clean-up things also wrt curl instead of flipping files all over the place
  tmpfile=$(mktemp -t regander::blob::PUT)
  cat /dev/stdin > "$tmpfile"

  # Now do a monolithic PUT
  local digest
  local length
  digest="$(dc::crypto::shasum::compute "$tmpfile")"
  length=$(wc -c "$tmpfile" | awk '{print $1}')

  # Only upload if the blob is not there
  if ! _=$(regander::blob::HEAD "$name" "$digest" 2>/dev/null); then
    dc::logger::info "Layer is not up-there. Uploading."
    # Get an upload id
    _regander::client "$name/blobs/uploads/" POST ""
    _regander::expect 202

    _regander::straightwithauth "$DC_HTTP_HEADER_LOCATION&digest=$digest" PUT "$tmpfile" \
      "Content-Type: $type" \
      "Content-Length: $length"
    _regander::expect 201
  else
    dc::logger::info "Layer $name $digest is already there and mounted. No need to do anything."
  fi

  dc::output::json "{\"digest\": \"$digest\", \"size\": $length, \"mediaType\": \"$type\"}"
}
