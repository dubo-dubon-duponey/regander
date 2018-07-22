#!/usr/bin/env bash

version=$(REGISTRY_USERNAME=anonymous ./regander -s version GET)
assert::equal version '"registry/2.0"'
