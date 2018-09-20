#!/usr/bin/env bash

readonly GRAMMAR_ALPHANUM="[a-z0-9]+"
readonly GRAMMAR_SEP="(?:[._]|__|[-]*)"

registry::grammar::name(){
  local subject="$1"
  local ignoreError=$2
  IS_VALID=$(echo "$subject" | grep -Ei "^$GRAMMAR_ALPHANUM(?:$GRAMMAR_SEP$GRAMMAR_ALPHANUM)*(?:/$GRAMMAR_ALPHANUM(?:$GRAMMAR_SEP$GRAMMAR_ALPHANUM)*)*$")

  if [ ${#subject} -ge 256 ]; then
    IS_VALID=
  fi

  if [ ! "$IS_VALID" ]; then
    if [ ! "$ignoreError" ]; then
      dc::logger::error "Name $subject does not pass the grammar validation!"
      exit "$ERROR_ARGUMENT_INVALID"
    fi
    dc::logger::warning "Name $subject does not pass the grammar validation!"
  fi
}

registry::grammar::tag(){
  local subject="$1"
  local ignoreError=$2
  IS_VALID=$(echo "$subject" | grep -E "^[a-zA-Z0-9_][a-zA-Z0-9_.-]{0,127}$")
  if [ ! "$IS_VALID" ]; then
    if [ ! "$ignoreError" ]; then
      dc::logger::error "Tag $subject does not pass the grammar validation!"
      exit "$ERROR_ARGUMENT_INVALID"
    fi
    dc::logger::warning "Tag $subject does not pass the grammar validation!"
  fi
}

registry::grammar::digest(){
  local subject="$1"
  local ignoreError=$2
  IS_VALID=$(echo "$subject" | grep -E "^[A-Za-z][A-Za-z0-9]*(?:[-_+.][A-Za-z][A-Za-z0-9]*)*:[A-Fa-f0-9]{32,}$")
  if [ ! "$IS_VALID" ]; then
    if [ ! "$ignoreError" ]; then
      dc::logger::error "Digest $subject does not pass the grammar validation!"
      exit "$ERROR_ARGUMENT_INVALID"
    fi
    dc::logger::warning "Digest $subject does not pass the grammar validation!"
  fi
}

registry::grammar::tagdigest(){
  local subject="$1"
  local ignoreError=$2
  IS_VALID=$(echo "$subject" | grep -E "^(?:[a-zA-Z0-9_][a-zA-Z0-9_.-]{0,127}|sha256:[a-f0-9]{64})$")
  if [ ! "$IS_VALID" ]; then
    if [ ! "$ignoreError" ]; then
      dc::logger::error "Digest or tag $subject does not pass the grammar validation!"
      exit "$ERROR_ARGUMENT_INVALID"
    fi
    dc::logger::warning "Digest or tag $subject does not pass the grammar validation!"
  fi
}

registry::grammar::digest::sha256(){
  local subject="$1"
  local ignoreError=$2
  IS_VALID=$(echo "$subject" | grep -E "^sha256:[a-f0-9]{64}$")
  if [ ! "$IS_VALID" ]; then
    if [ ! "$ignoreError" ]; then
      dc::logger::error "SHA $subject does not pass the grammar validation!"
      exit "$ERROR_ARGUMENT_INVALID"
    fi
    dc::logger::warning "SHA $subject does not pass the grammar validation!"
  fi
}
