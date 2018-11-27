#!/usr/bin/env bash

readonly GRAMMAR_ALPHANUM="[a-z0-9]+"
readonly GRAMMAR_SEP="(?:[._]|__|[-]*)"
readonly GRAMMAR_NAME="^$GRAMMAR_ALPHANUM(?:$GRAMMAR_SEP$GRAMMAR_ALPHANUM)*(?:/$GRAMMAR_ALPHANUM(?:$GRAMMAR_SEP$GRAMMAR_ALPHANUM)*)*$"
readonly GRAMMAR_TAG="^[a-z0-9_][a-z0-9_.-]{0,127}$"
readonly GRAMMAR_DIGEST="^[a-z][a-z0-9]*(?:[-_+.][a-z][a-z0-9]*)*:[a-f0-9]{32,}$"
readonly GRAMMAR_DIGEST_SHA256="^sha256:[a-f0-9]{64}$"
readonly GRAMMAR_TAG_DIGEST="^(?:[a-z0-9_][a-z0-9_.-]{0,127}|sha256:[a-f0-9]{64})$"
