#!/usr/bin/env bash

##########
# HEAD
##########

# Regular manifest
manifest=$(REGISTRY_USERNAME=anonymous ./regander -s manifest HEAD dubodubonduponey/regander test-v2)
type=$(echo $manifest | jq -r .type)
echo $manifest
assert::equal type 'application/vnd.docker.distribution.manifest.v2+json'

# Downgraded to v1
manifest=$(REGISTRY_USERNAME=anonymous ./regander -s --downgrade=true manifest HEAD dubodubonduponey/regander test-v2)
type=$(echo $manifest | jq -r .type)

assert::equal type 'application/vnd.docker.distribution.manifest.v1+prettyjws'

# By digest
manifest=$(REGISTRY_USERNAME=anonymous ./regander -s manifest HEAD library/nginx sha256:eaa79ecb1308dccbdc478ddd1fb3a77bdb0846b05987e8e08f11661b2cc55f8f)
type=$(echo $manifest | jq -r .type)
length=$(echo $manifest | jq -r .length)
digest=$(echo $manifest | jq -r .digest)

assert::equal type 'application/vnd.docker.distribution.manifest.v2+json'
assert::equal length '1153'
assert::equal digest 'sha256:eaa79ecb1308dccbdc478ddd1fb3a77bdb0846b05987e8e08f11661b2cc55f8f'

# Manifest list
manifest=$(REGISTRY_USERNAME=anonymous ./regander -s manifest HEAD library/nginx sha256:56a9367b64eaef37894842a6f7a19a0ef8e7bd5de964aa844a70b3e2d758033c)
type=$(echo $manifest | jq -r .type)
length=$(echo $manifest | jq -r .length)
digest=$(echo $manifest | jq -r .digest)

assert::equal type 'application/vnd.docker.distribution.manifest.list.v2+json'
assert::equal length '2035'
assert::equal digest 'sha256:56a9367b64eaef37894842a6f7a19a0ef8e7bd5de964aa844a70b3e2d758033c'

# Plugin

##########
# GET
##########

# Regular manifest
manifest=$(REGISTRY_USERNAME=anonymous ./regander -s manifest GET library/nginx alpine)
version=$(echo $manifest | jq -r .schemaVersion)
type=$(echo $manifest | jq -r .mediaType)

assert::equal version '2'
assert::equal type 'application/vnd.docker.distribution.manifest.v2+json'

# Downgraded to v1
manifest=$(REGISTRY_USERNAME=anonymous ./regander -s --downgrade=true manifest GET library/nginx alpine)
version=$(echo $manifest | jq .schemaVersion)
assert::equal version '1'

# By digest
manifest=$(REGISTRY_USERNAME=anonymous ./regander -s manifest GET library/nginx sha256:eaa79ecb1308dccbdc478ddd1fb3a77bdb0846b05987e8e08f11661b2cc55f8f)
type=$(echo $manifest | jq .mediaType)
version=$(echo $manifest | jq .schemaVersion)

assert::equal version '2'
assert::equal type '"application/vnd.docker.distribution.manifest.v2+json"'
