#!/usr/bin/env bash

assert::null(){
  if [ ! -z "$(eval echo \"\$$1\")" ]; then
    echo "[$(date)] [FATAL] Expecting '$1' to be null, was '$(eval echo \"\$$1\")'"
    exit 1
  fi
}

assert::notnull(){
  if [ -z "$(eval echo \"\$$1\")" ]; then
    echo "[$(date)] [FATAL] Expecting '$1' to not be null"
    exit 1
  fi
}

assert::equal(){
  if [ "$(eval echo \"\$$1\")" != "$2" ]; then
    echo "[$(date)] [FATAL] Expecting '$1' to be equal to '$2', was '$(eval echo \"\$$1\")'"
    exit 1
  fi
}

assert::notequal(){
  if [ "$(eval echo \"\$$1\")" == "$2" ]; then
    echo "[$(date)] [FATAL] Expecting '$1' to not be '$2'"
    exit 1
  fi
}
