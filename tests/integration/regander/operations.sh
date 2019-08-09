#!/usr/bin/env bash

# Pushing a blob
blob="2341"
shasum=$(printf "%s" "$blob" | shasum -a 256 -)
shasum="sha256:${shasum%% *}"

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


helperHUB(){
  export REGISTRY_USERNAME=$HUB_TEST_USERNAME
  export REGISTRY_PASSWORD=$HUB_TEST_PASSWORD
  REGISTRY=https://registry-1.docker.io
  imagename=$REGISTRY_USERNAME/regander-integration-test
  otherimagename=$REGISTRY_USERNAME/regander-also-integration-test
  tagname=that-tag-name
}

helperHUBAnonymous(){
  export REGISTRY_USERNAME=""
  export REGISTRY_PASSWORD=""
  REGISTRY=https://registry-1.docker.io
  imagename=$HUB_TEST_USERNAME/regander-integration-test
  otherimagename=$HUB_TEST_USERNAME/regander-also-integration-test
  tagname=that-tag-name
}

helperOSS(){
  export REGISTRY_USERNAME=
  export REGISTRY_PASSWORD=
  REGISTRY=http://localhost:5000
  imagename=dubogus/regander-integration-test
  otherimagename=dubogus/regander-also-integration-test
  tagname=that-tag-name
}

helperVersion(){
  # Version
  result=$(regander -s --registry=$REGISTRY version GET)
  exit=$?
  result="$(echo "$result" | jq -rcj .)"

  dc-tools::assert::equal "exit code" "0" "$exit"
  dc-tools::assert::equal "result" "registry/2.0" "$result"
}

helperCatalog(){
  # Empty catalog
  result=$(regander -s --registry=$REGISTRY catalog)
  exit=$?
  result="$(echo "$result" | jq -rcj .)"

  if [ "$1" ]; then
    dc-tools::assert::equal "catalog GET" "$exit" "0"
    dc-tools::assert::equal "$1" "$result"
  else
    dc-tools::assert::equal "catalog GET" "$exit" "13"
    dc-tools::assert::equal "$result" '{"errors":[{"code":"UNAUTHORIZED","message":"authentication required","detail":[{"Type":"registry","Class":"","Name":"catalog","Action":"*"}]}]}'
  fi
}

helperBlobPush(){
  result=$(regander -s --registry=$REGISTRY blob PUT $imagename "application/vnd.oci.image.layer.v1.tar+gzip" < <(printf "%s" "$blob"))
  exit=$?
  result="$(echo "$result" | jq -rcj .digest)"

  dc-tools::assert::equal "blob PUT" "$exit" "0"
  dc-tools::assert::equal "$shasum" "$result"
}

helperBlobHead(){
  # Heading a blob
  result=$(regander -s --registry=$REGISTRY blob HEAD $imagename "$shasum")
  exit=$?
  result="$(echo "$result" | jq -rcj .)"

  type=$(echo "$result" | jq -rcj .type)
  length=$(echo "$result" | jq -rcj .size)
  location=$(echo "$result" | jq -rcj .location)
  dc-tools::assert::equal "blob HEAD" "0" "$exit"
  dc-tools::assert::equal "application/octet-stream" "$type"
  dc-tools::assert::equal "${#blob}" "$length"
  # If not redirected
  if [ "$1" ]; then
    dc-tools::assert::equal "$location" "$imagename/blobs/$shasum"
  fi
}

helperBlobGet(){
  # Getting a blob
  result=$(regander -s --registry=$REGISTRY blob GET $imagename "$shasum")
  exit=$?
  result="$(echo "$result" | jq -rcj .)"

  dc-tools::assert::equal "blob GET" "0" "$exit"
  dc-tools::assert::equal "$blob" "$result"
}

helperBlobMount(){
  # Mounting a blob
  result=$(regander -s --registry=$REGISTRY --from=$imagename blob MOUNT $otherimagename "$shasum")
  exit=$?
  result="$(echo "$result" | jq -rcj .)"

  digest=$(echo "$result" | jq -rcj .digest)
  length=$(echo "$result" | jq -rcj .size)
  location=$(echo "$result" | jq -rcj .location)
  dc-tools::assert::equal "blob MOUNT" "0" "$exit"
  dc-tools::assert::equal "$digest" "$shasum"
  dc-tools::assert::equal "$length" "0"
  # XXX HUB gives relative redirect
  # dc-tools::assert::equal "$location" "$REGISTRY/v2/$otherimagename/blobs/$shasum"
}

helperBlobDelete(){
  # Deleting a blob
  result=$(regander -s --registry=$REGISTRY blob DELETE $imagename "$shasum")
  exit=$?
  result="$(echo "$result" | jq -rcj .)"

  # XXX oss gives 20, Hub gives 13???? WTFF!!! It's changing!
  # dc-tools::assert::equal "blob DELETE" "$exit" "13"
  # dc-tools::assert::equal "$result" '{"errors":[{"code":"UNAUTHORIZED","message":"authentication required","detail":[{"Type":"repository","Class":"","Name":"dubogus/regander-integration-test","Action":"delete"}]}]}'
  dc-tools::assert::equal "blob DELETE" "20" "$exit"
  # XXX error is also different
  dc-tools::assert::equal "$result" '{"errors":[{"code":"UNSUPPORTED","message":"The operation is unsupported."}]}'
}

helperImagePut(){
  result=$(regander -s --registry=$REGISTRY manifest PUT $imagename $tagname < <(printf "%s" "$image"))
  exit=$?
  result="$(echo "$result" | jq -rcj .)"
  digest=$(echo "$result" | jq -rcj .digest)
  location=$(echo "$result" | jq -rcj .location)

  dc-tools::assert::equal "image PUT" "0" "$exit"
  dc-tools::assert::equal "$digest" "$ishasum"
  # XXX hub gives relative
  # dc-tools::assert::equal "$location" "$REGISTRY/v2/$imagename/manifests/$ishasum"
}

helperImageHead(){
  # HEAD image
  result=$(regander -s --registry=$REGISTRY manifest HEAD $imagename "$ishasum")
  exit=$?
  result="$(echo "$result" | jq -rcj .)"

  type=$(echo "$result" | jq -rcj .type)
  length=$(echo "$result" | jq -rcj .size)
  location=$(echo "$result" | jq -rcj .location)
  dc-tools::assert::equal "image HEAD" "0" "$exit"
  dc-tools::assert::equal "$type" "application/vnd.docker.distribution.manifest.v2+json"
  dc-tools::assert::equal "$length" "${#image}"
  dc-tools::assert::equal "$digest" "$ishasum"

  result=$(regander -s --registry=$REGISTRY manifest HEAD $imagename "$tagname")
  exit=$?
  result="$(echo "$result" | jq -rcj .)"

  type=$(echo "$result" | jq -rcj .type)
  length=$(echo "$result" | jq -rcj .size)
  location=$(echo "$result" | jq -rcj .location)
  dc-tools::assert::equal "image HEAD" "0" "$exit"
  dc-tools::assert::equal "$type" "application/vnd.docker.distribution.manifest.v2+json"
  dc-tools::assert::equal "$length" "${#image}"
  dc-tools::assert::equal "$digest" "$ishasum"
}

helperImageGet(){
  # GET image
  result=$(regander -s --registry=$REGISTRY manifest GET $imagename "$ishasum")
  exit=$?
  result="$(echo "$result" | jq -rcj .)"

  dc-tools::assert::equal "image GET" "0" "$exit"
  dc-tools::assert::equal "$image" "$result"

  result=$(regander -s --registry=$REGISTRY manifest GET $imagename "$tagname")
  exit=$?
  result="$(echo "$result" | jq -rcj .)"

  dc-tools::assert::equal "image GET" "0" "$exit"
  dc-tools::assert::equal "$image" "$result"
}

helperImageDelete(){
  # DELETE image
  result=$(regander -s --registry=$REGISTRY manifest DELETE $imagename "$ishasum")
  exit=$?
  result="$(echo "$result" | jq -rcj .)"

  dc-tools::assert::equal "image DELETE" "20" "$exit"
  dc-tools::assert::equal "$result" '{"errors":[{"code":"UNSUPPORTED","message":"The operation is unsupported."}]}'

  result=$(regander -s --registry=$REGISTRY manifest DELETE $imagename "$tagname")
  exit=$?
  result="$(echo "$result" | jq -rcj .)"

  dc-tools::assert::equal "image DELETE" "20" "$exit"
  dc-tools::assert::equal "$result" '{"errors":[{"code":"UNSUPPORTED","message":"The operation is unsupported."}]}'
}

helperTagsGet(){
  ###########################
  # Tags
  ###########################

  result=$(regander -s --registry=$REGISTRY tags GET $imagename | jq -rcj .)
  exit=$?
  dc-tools::assert::equal "0" "$exit"
  dc-tools::assert::equal "{\"name\":\"$imagename\",\"tags\":[\"$tagname\"]}" "$result"
}

testVersion(){
  helperHUB
  helperVersion
  # Anon
  helperHUBAnonymous
  helperVersion
}

testVersionOSS(){
  if command -v docker >/dev/null; then
    helperOSS
    helperVersion
  fi
}

testCatalog(){
  helperHUB
  helperCatalog
  # Anon
  helperHUBAnonymous
  helperCatalog
}

testCatalogOSS(){
  if command -v docker >/dev/null; then
    helperOSS
    helperCatalog '{"repositories":[]}'
  fi
}

testBlobPush(){
  helperHUB
  helperBlobPush
}

testBlobPushOSS(){
  if command -v docker >/dev/null; then
    helperOSS
    helperBlobPush
  fi
}

testBlobHead(){
  helperHUB
  helperBlobHead
}

testBlobHeadOSS(){
  if command -v docker >/dev/null; then
    helperOSS
    helperBlobHead testlocation
  fi
}

testBlobGet(){
  helperHUB
  helperBlobGet
}

testBlobGetOSS(){
  if command -v docker >/dev/null; then
    helperOSS
    helperBlobGet
  fi
}

testBlobMount(){
  helperHUB
  helperBlobMount
}

testBlobMountOSS(){
  if command -v docker >/dev/null; then
    helperOSS
    helperBlobMount
  fi
}

testBlobDelete(){
  helperHUB
  helperBlobDelete
  if command -v docker >/dev/null; then
    helperOSS
    helperBlobDelete
  fi
}

testCatalogAgain(){
  helperHUB
  helperCatalog
  if command -v docker >/dev/null; then
    helperOSS
    helperCatalog "{\"repositories\":[\"$otherimagename\",\"$imagename\"]}"
  fi
}

testImagePut(){
  helperHUB
  helperImagePut
  if command -v docker >/dev/null; then
    helperOSS
    helperImagePut
  fi
}

testImageHead(){
  helperHUB
  helperImageHead
  if command -v docker >/dev/null; then
    helperOSS
    helperImageHead
  fi
  # Anon
  helperHUBAnonymous
  helperImageHead
}

testImageGet(){
  helperHUB
  helperImageGet
  if command -v docker >/dev/null; then
    helperOSS
    helperImageGet
  fi
  # Anon
  helperHUBAnonymous
  helperImageGet
}

testImageDelete(){
  helperHUB
  helperImageDelete
  if command -v docker >/dev/null; then
    helperOSS
    helperImageDelete
  fi
}

testTagsGet(){
  helperHUB
  helperTagsGet
  if command -v docker >/dev/null; then
    helperOSS
    helperTagsGet
  fi
  # Anon
  helperHUBAnonymous
  helperTagsGet
}

