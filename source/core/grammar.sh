#!/usr/bin/env bash

readonly GRAMMAR_ALPHANUM="[a-z0-9]+"
readonly GRAMMAR_SEP="(?:[._]|__|[-]*)"
# shellcheck disable=SC2034
readonly GRAMMAR_NAME="^$GRAMMAR_ALPHANUM(?:$GRAMMAR_SEP$GRAMMAR_ALPHANUM)*(?:/$GRAMMAR_ALPHANUM(?:$GRAMMAR_SEP$GRAMMAR_ALPHANUM)*)*$"
# shellcheck disable=SC2034
readonly GRAMMAR_TAG="^[a-z0-9_][a-z0-9_.-]{0,127}$"
# shellcheck disable=SC2034
readonly GRAMMAR_DIGEST="^[a-z][a-z0-9]*(?:[-_+.][a-z][a-z0-9]*)*:[a-f0-9]{32,}$"
# shellcheck disable=SC2034
readonly GRAMMAR_DIGEST_SHA256="^sha256:[a-f0-9]{64}$"
# shellcheck disable=SC2034
readonly GRAMMAR_TAG_DIGEST="^(?:[a-z0-9_][a-z0-9_.-]{0,127}|sha256:[a-f0-9]{64})$"
