#!/usr/bin/env bash

REGISTRY=
imagename=dubogus/regander-integration-test
otherimagename=dubogus/regander-also-integration-test
tagname=that-tag-name

# Version
result=$(regander -s --registry=$REGISTRY version GET)
exit=$?
result="$(echo "$result" | jq -rcj .)"

dc-tools::assert::equal "$exit" "0" "version GET"
dc-tools::assert::equal "$result" "registry/2.0"

# Empty catalog
result=$(regander -s --registry=$REGISTRY catalog GET)
exit=$?
result="$(echo "$result" | jq -rcj .)"

dc-tools::assert::equal "$exit" "13" "catalog GET"
dc-tools::assert::equal "$result" '{"errors":[{"code":"UNAUTHORIZED","message":"authentication required","detail":[{"Type":"registry","Class":"","Name":"catalog","Action":"*"}]}]}'

###########################
# Blobs
###########################
# Pushing a blob
blob="1234"
shasum=$(printf "%s" "$blob" | shasum -a 256 -)
shasum="sha256:${shasum%% *}"

result=$(regander -s --registry=$REGISTRY blob PUT $imagename < <(printf "%s" "$blob"))
exit=$?
result="$(echo "$result" | jq -rcj .)"

dc-tools::assert::equal "$exit" "0" "blob PUT"
dc-tools::assert::equal "$result" "$shasum"

# Heading a blob
result=$(regander -s --registry=$REGISTRY blob HEAD $imagename "$shasum")
exit=$?
result="$(echo "$result" | jq -rcj .)"

type=$(echo "$result" | jq -rcj .type)
length=$(echo "$result" | jq -rcj .length)
location=$(echo "$result" | jq -rcj .location)
dc-tools::assert::equal "$exit" "0" "blob HEAD"
dc-tools::assert::equal "$type" "application/octet-stream"
dc-tools::assert::equal "$length" "${#blob}"
# Redirected, so...
#dc-tools::assert::equal "$location" "$imagename/blobs/$shasum"

# Getting a blob
result=$(regander -s --registry=$REGISTRY blob GET $imagename "$shasum")
exit=$?
result="$(echo "$result" | jq -rcj .)"

dc-tools::assert::equal "$exit" "0" "blob GET"
dc-tools::assert::equal "$result" "$blob"

# Mounting a blob
result=$(regander -s --registry=$REGISTRY blob MOUNT $otherimagename "$shasum" $imagename)
exit=$?
result="$(echo "$result" | jq -rcj .)"

digest=$(echo "$result" | jq -rcj .digest)
length=$(echo "$result" | jq -rcj .length)
location=$(echo "$result" | jq -rcj .location)
dc-tools::assert::equal "$exit" "0" "blob MOUNT"
dc-tools::assert::equal "$digest" "$shasum"
dc-tools::assert::equal "$length" "0"
# XXX HUB gives relative redirect
#dc-tools::assert::equal "$location" "$REGISTRY/v2/$otherimagename/blobs/$shasum"

# Deleting a blob
result=$(regander -s --registry=$REGISTRY blob DELETE $imagename "$shasum")
exit=$?
result="$(echo "$result" | jq -rcj .)"

# XXX oss gives 20, Hub gives 13???? WTFF!!! It's changing!
# dc-tools::assert::equal "$exit" "13" "blob DELETE"
# dc-tools::assert::equal "$result" '{"errors":[{"code":"UNAUTHORIZED","message":"authentication required","detail":[{"Type":"repository","Class":"","Name":"dubogus/regander-integration-test","Action":"delete"}]}]}'
dc-tools::assert::equal "$exit" "20" "blob DELETE"
# XXX error is also different
dc-tools::assert::equal "$result" '{"errors":[{"code":"UNSUPPORTED","message":"The operation is unsupported."}]}'

# Catalog now has images
result=$(regander -s --registry=$REGISTRY catalog GET)
exit=$?
result="$(echo "$result" | jq -rcj .)"

dc-tools::assert::equal "$exit" "13" "catalog GET"
dc-tools::assert::equal "$result" '{"errors":[{"code":"UNAUTHORIZED","message":"authentication required","detail":[{"Type":"registry","Class":"","Name":"catalog","Action":"*"}]}]}'

###########################
# Images
###########################

# Pushing an image
image='{
   "schemaVersion": 2,
   "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
   "config": {
      "mediaType": "application/vnd.docker.container.image.v1+json",
      "size": 4,
      "digest": "'$shasum'"
   },
   "layers": [
      {
         "mediaType": "application/vnd.docker.image.rootfs.diff.tar.gzip",
         "size": '${#blob}',
         "digest": "'$shasum'"
      }
   ]
}'
image=$(printf "%s" "$image" | jq -cj .)
ishasum=$(printf "%s" "$image" | shasum -a 256 -)
ishasum="sha256:${ishasum%% *}"


result=$(regander -s --registry=$REGISTRY manifest PUT $imagename $tagname < <(printf "%s" "$image"))
exit=$?
result="$(echo "$result" | jq -rcj .)"
digest=$(echo "$result" | jq -rcj .digest)
location=$(echo "$result" | jq -rcj .location)

dc-tools::assert::equal "$exit" "0" "image PUT"
dc-tools::assert::equal "$digest" "$ishasum"
# XXX hub gives relative
#dc-tools::assert::equal "$location" "$REGISTRY/v2/$imagename/manifests/$ishasum"

# HEAD image
result=$(regander -s --registry=$REGISTRY manifest HEAD $imagename "$ishasum")
exit=$?
result="$(echo "$result" | jq -rcj .)"

type=$(echo "$result" | jq -rcj .type)
length=$(echo "$result" | jq -rcj .length)
location=$(echo "$result" | jq -rcj .location)
dc-tools::assert::equal "$exit" "0" "image HEAD"
dc-tools::assert::equal "$type" "application/vnd.docker.distribution.manifest.v2+json"
dc-tools::assert::equal "$length" "${#image}"
dc-tools::assert::equal "$digest" "$ishasum"

result=$(regander -s --registry=$REGISTRY manifest HEAD $imagename "$tagname")
exit=$?
result="$(echo "$result" | jq -rcj .)"

type=$(echo "$result" | jq -rcj .type)
length=$(echo "$result" | jq -rcj .length)
location=$(echo "$result" | jq -rcj .location)
dc-tools::assert::equal "$exit" "0" "image HEAD"
dc-tools::assert::equal "$type" "application/vnd.docker.distribution.manifest.v2+json"
dc-tools::assert::equal "$length" "${#image}"
dc-tools::assert::equal "$digest" "$ishasum"

# GET image
result=$(regander -s --registry=$REGISTRY manifest GET $imagename "$ishasum")
exit=$?
result="$(echo "$result" | jq -rcj .)"

dc-tools::assert::equal "$exit" "0" "image GET"
dc-tools::assert::equal "$result" "$image"

result=$(regander -s --registry=$REGISTRY manifest GET $imagename "$tagname")
exit=$?
result="$(echo "$result" | jq -rcj .)"

dc-tools::assert::equal "$exit" "0" "image GET"
dc-tools::assert::equal "$result" "$image"

# DELETE image
result=$(regander -s --registry=$REGISTRY manifest DELETE $imagename "$ishasum")
exit=$?
result="$(echo "$result" | jq -rcj .)"

dc-tools::assert::equal "$exit" "20" "image DELETE"
dc-tools::assert::equal "$result" '{"errors":[{"code":"UNSUPPORTED","message":"The operation is unsupported."}]}'

result=$(regander -s --registry=$REGISTRY manifest DELETE $imagename "$tagname")
exit=$?
result="$(echo "$result" | jq -rcj .)"

dc-tools::assert::equal "$exit" "20" "image DELETE"
dc-tools::assert::equal "$result" '{"errors":[{"code":"UNSUPPORTED","message":"The operation is unsupported."}]}'


###########################
# Tags
###########################

result=$(regander -s --registry=$REGISTRY tags GET $imagename | jq -rcj .)
exit=$?
dc-tools::assert::equal "$exit" "0"
dc-tools::assert::equal "$result" "{\"name\":\"$imagename\",\"tags\":[\"$tagname\"]}"
