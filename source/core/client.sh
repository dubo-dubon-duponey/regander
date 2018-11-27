#!/usr/bin/env bash

# Depends on:
# REGANDER_ACCEPT
# REGANDER_UA
# REGANDER_REGISTRY
# REGANDER_USERNAME
# REGANDER_PASSWORD

_regander::straightwithauth(){
  local url="$1"
  local method="$2"
  local payload="$3"
  shift
  shift
  shift
  local auth=
  # For first try, always use any existing token
  if [ "$DC_JWT_TOKEN" ]; then
    auth="Authorization: Bearer $DC_JWT_TOKEN"
  fi

  # Do the request
  if [ "$payload" ]; then
    _wrapper::request "$url" "$method" "-" "$auth" "$@" < "$payload"
  else
    _wrapper::request "$url" "$method" "" "$auth" "$@"
  fi
}

_regander::anonymous(){
  _wrapper::request "$@"
  _wrapper::request::postprocess
}

# Simple wrapper around the actual client that deals with some error conditions, plus UA and Accept header
_regander::client(){
  _regander::http "$REGANDER_REGISTRY/$1" "${@:2}"
  _wrapper::request::postprocess
}

#####################################
# Authentication helper
#####################################
_regander::authenticate() {
  # Query the auth server (1) for the service (2) with scope (3)
  local url="${1}?service=${2}"
  local scope="$3"
  shift
  shift
  shift

  # Why on earth is garant not able to take a single scope param with spaces? this is foobared Docker!
  for i in $scope; do
    url="$url&scope=$(dc::http::uriencode "$i")"
  done

  # SO...
  while true; do
    local authHeader=
    # Fetch credentials, if we don't have some to replay already
    if [ ! "$REGANDER_USERNAME" ]; then
      dc::prompt::credentials "Please provide your username (or press enter for anonymous): " REGANDER_USERNAME "password: " REGANDER_PASSWORD
      export REGANDER_USERNAME
      export REGANDER_PASSWORD
    fi

    # If we have something, build the basic auth header
    if [ "$REGANDER_USERNAME" ]; then
      # Generate the basic auth token with the known user
      authHeader="Basic $(printf "%s" "${REGANDER_USERNAME}:${REGANDER_PASSWORD}" | base64)"
    fi

    # Query the service
    dc::http::request "$url" GET "" "Authorization: $authHeader" "User-Agent: $REGANDER_UA" "$@"

    if [ "$DC_HTTP_STATUS" == "401" ]; then
      dc::logger::warning "Wrong username or password."
      # No way to get credentials, we are done here
      if [ ! -t 1 ] || [ ! -t 0 ]; then
        break
      fi
      # Reset username, since it's invalid and continue to retry
      REGANDER_USERNAME=
      continue
    fi

    # Anything but 200 or 401 is abnormal - in that case, break out and let downstream deal with it
    if [ "$DC_HTTP_STATUS" != "200" ]; then
      break
    fi

    # A 200 means authentication was successful, let's read the token and understand what just went down
    dc::jwt::read "$(jq '.token' < "$DC_HTTP_BODY" | xargs echo)"

    # TODO Actually validate the scope in full
    if [ ! "$scope" ] || [ "$DC_JWT_ACCESS" != "[]" ]; then
      dc::logger::debug "[regander] JWT scope: $scope"
      break
    fi

    # We got kicked on the scope...
    dc::logger::warning "The user $REGANDER_USERNAME was denied permission for the requested scope. Maybe the target doesn't exist, or you need a different account to access it."
    # Are we done? Move on.
    if [ ! -t 1 ] || [ ! -t 0 ]; then
      break
    fi
    # Otherwise, we are in for another try
    REGANDER_USERNAME=
  done
}

#####################################
# Generic registry client helper, with authentication and http handling
#####################################

_regander::http(){
  local endpoint="$1"
  local method="$2"
  local payload="$3"
  shift
  shift
  shift

  local auth=
  # For first try, always use any existing token
  if [ "$DC_JWT_TOKEN" ]; then
    auth="Authorization: Bearer $DC_JWT_TOKEN"
  fi

  # Do the request
  if [ "$payload" ]; then
    _wrapper::request "$endpoint" "$method" "-" "$auth" "$@" < <(printf "%s" "$payload")
  else
    _wrapper::request "$endpoint" "$method" "" "$auth" "$@"
  fi

  # If it's a failed request, check what we have, starting with reading the header
  # TODO implement support for basic auth
  local auth=${DC_HTTP_HEADER_WWW_AUTHENTICATE}
  local service=
  local realm=
  local scope=
  local error=
  local value=

  while [ -n "$auth" ] && [ "$auth" != "$value\"" ]; do
    key=${auth%%=*}
    key=${key#*Bearer }
    value=${auth#*=\"}
    auth=${value#*\",}
    value=${value%%\"*}
    read -r "${key?}" < <(printf "%s" "$value")
  done

  dc::logger::debug "[regander] JWT service: $service" "[regander] JWT realm: $realm" "[regander] JWT scope: $scope" "[regander] JWT error: $error"

  # Did we get anything but a 401, and no scope error? We are good to go
  if [ "${DC_HTTP_STATUS}" != "401" ] && [ ! "$error" ]; then
    return
  fi

  # If we got an error at this point, it means we have a token with unsufficient scope
  if [ "$error" ]; then
    dc::logger::info "[JWT] Got an authorization error: $error. Going to try and re-authenticate with existing credentials and the specified scope."
  fi

  # Whether we got a 401 or an error, let's try against the auth server
  _regander::authenticate "$realm" "$service" "$scope" "$@"

  # If we are out of the authentication loop with anything but a 200, stop now
  if [ "$DC_HTTP_STATUS" != "200" ]; then
    return
  fi

  # Authenticate returned successfully, means we have a token to try again. Note though that the scope may still be unsufficient at this point.
  auth="Authorization: Bearer $DC_JWT_TOKEN"
  # Replay the transaction
  if [ "$payload" ]; then
    _wrapper::request "$endpoint" "$method" "-" "$auth" "$@" < <(printf "%s" "$payload")
  else
    _wrapper::request "$endpoint" "$method" "" "$auth" "$@"
  fi
}


_wrapper::request(){
  local ar=()
  for i in "${REGANDER_ACCEPT[@]}"; do
    ar+=("Accept: $i")
  done

  dc::http::request "$@" "${ar[@]}" "User-Agent: $REGANDER_UA"
}

_wrapper::request::postprocess(){
  # Acceptable status code exit now
  if [ "${DC_HTTP_STATUS:0:1}" == "2" ] || [ "${DC_HTTP_STATUS:0:1}" == "3" ]; then
    return
  fi

  # 400 errors should sport a readable error body
  #{
  #  "errors:" [{
  #          "code": <error identifier>,
  #          "message": <message describing condition>,
  #          "detail": <unstructured>
  #      },
  #      ...
  #  ]
  #}

  # Otherwise, dump the body!
  dc::http::dump::headers
  dc::http::dump::body

  # Try to produce the body if it's valid json (downstream clients may be interested in inspecting the registry error)
  jq '.' "$DC_HTTP_BODY" 2>/dev/null

  case $DC_HTTP_STATUS in
  "400")
    dc::logger::error "Something is badly borked. Check out above."
    exit "$ERROR_REGISTRY_MALFORMED"
    ;;
  "401")
    # This should happen only:
    # - if we do NOT send a token to the registry, which we always end-up doing after a round-trip
    # - if the credentials sent to garant are invalid
    dc::logger::error "You can't access that resource."
    exit "$ERROR_REGISTRY_MY_NAME_IS"
    ;;
  "404")
    dc::logger::error "The requested resource doesn't exist (at least for you!)."
    exit "$ERROR_REGISTRY_THIS_IS_A_MIRAGE"
    ;;
  "405")
    dc::logger::error "This registry of yours does not support the requested operation. Maybe it's a cache? Or a very old dog?"
    exit "$ERROR_REGISTRY_UNKNOWN"
    ;;
  "429")
    dc::logger::error "WOOOO! Slow down tiger! Registry says you are doing too many requests."
    exit "$ERROR_REGISTRY_SLOW_DOWN_TIGER"
    ;;
  "")
    dc::logger::error "Network issue... Recommended: check your pooch whereabouts. Now, check these chewed-up network cables."
    exit "$ERROR_NETWORK"
    ;;
  esac

  # Maybe a 5xx, then exit
  if [ "${DC_HTTP_STATUS:0:1}" == "5" ]; then
    dc::logger::error "BONKERS! A 5xx response code. You broke that poor lil' registry, you meany!"
    exit "$ERROR_REGISTRY_TITS_UP"
  fi

  # Otherwise...
  dc::logger::error "Mayday! Mayday!"
  exit "$ERROR_REGISTRY_UNKNOWN"
}
