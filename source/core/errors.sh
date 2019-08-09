#!/usr/bin/env bash
##########################################################################
# Errors
# ------
# Additional errors on top of dubo core defined errors
##########################################################################

# Registry errors

## 400
true
# shellcheck disable=SC2034
readonly ERROR_REGISTRY_MALFORMED=12
## 401, possibly with a JWT scope error
# shellcheck disable=SC2034
readonly ERROR_REGISTRY_MY_NAME_IS=13
## 404, possibly with a JWT scope error
# shellcheck disable=SC2034
readonly ERROR_REGISTRY_THIS_IS_A_MIRAGE=14
## 405, registry doesn't support this operation
# shellcheck disable=SC2034
readonly ERROR_REGISTRY_COUGH=15
## 429: throttling
# shellcheck disable=SC2034
readonly ERROR_REGISTRY_SLOW_DOWN_TIGER=16
## 5xx
# shellcheck disable=SC2034
readonly ERROR_REGISTRY_TITS_UP=17
## Anything else that is not caught already
# shellcheck disable=SC2034
readonly ERROR_REGISTRY_UNKNOWN=20

# API
## Doesn't return the expected http header with the API version
# shellcheck disable=SC2034
readonly ERROR_SERVER_NOT_WHAT_YOU_THINK=30
