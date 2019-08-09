#!/usr/bin/env bash

helperHUB(){
  export REGISTRY_USERNAME=$HUB_TEST_USERNAME
  export REGISTRY_PASSWORD=$HUB_TEST_PASSWORD
  REGISTRY=https://registry-1.docker.io
  #imagename=$REGISTRY_USERNAME/regander-integration-test
  #otherimagename=$REGISTRY_USERNAME/regander-also-integration-test
  #tagname=that-tag-name
}

helperOSS(){
  export REGISTRY_USERNAME=
  export REGISTRY_PASSWORD=
  REGISTRY=http://localhost:5000
  #imagename=dubogus/regander-integration-test
  #otherimagename=dubogus/regander-also-integration-test
  #tagname=that-tag-name
}


helperDownload(){
  # Version
  result=$(reghigh -s --registry=$REGISTRY download library/nginx)
  exit=$?
  result="$(printf "%s" "$result" | jq -rcj .)"

  dc-tools::assert::equal "exit code" "0" "$exit"
}
