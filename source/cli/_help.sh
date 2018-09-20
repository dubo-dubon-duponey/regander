#!/usr/bin/env bash

_help::section(){
  tput setaf 1
  printf "%s\\n" "-------------------------------------------"
  printf "%s\\n" "$@"
  printf "%s\\n" "-------------------------------------------"
  tput op
  printf "\\n"
}

_help::item(){
  tput setaf 2
  printf "%s\\n" ">>>>> $* <<<<<"
  tput op
  printf "\\n"
}

_help::example(){
  tput setaf 3
  printf "%s\\n" "$*"
  tput op
  printf "\\n"
}

_help::exampleindent(){
  tput setaf 3
  printf "\\t%s\\n" "$*"
  tput op
  printf "\\n"
}

# Need help?
dc::commander::help(){
  local name="$1"
  local version="$2"
  local license=$3
  #local shortdesc=$4
  #local shortusage=$5

  printf "%s\\n" "$name, version $version, released under $license"
  printf "\\t%s\\n" "> a fancy piece of shcript implementing a standalone Docker registry protocol client"
  printf "\\n"
  printf "%s\\n" "Usage:"
  printf "\\t%s\\n" "$name [options] endpoint METHOD [object] [reference] [origin-object]"

  _help::section "Endpoints"

  _help::item "1. Version (GET)"

  _help::example "$name [--registry=foo] [-s] version GET"
  printf "%s\\n" "Examples:"
  printf "\\t%s\\n" "a. Get the Hub protocol version, interactively asking for credentials"
  _help::exampleindent "$name -s version GET"
  printf "\\t%s\\n" "b. Get the protocol version from registry-1.docker.io using anonymous and pipe it to jq"
  _help::exampleindent "$name -s --registry=https://registry-1.docker.io version GET | jq"

  _help::item "2. Tag list (GET)"

  _help::example "$name [--registry=foo] [-s] tags GET imagename"
  printf "%s\\n" "Examples:"
  printf "\\t%s\\n" "a. Get all tags for the official nginx image"
  _help::exampleindent "$name -s tags GET library/nginx"
  printf "\\t%s\\n" "b. Same, but filter out only the tags containing 'alpine' in their name"
  _help::exampleindent "$name -s tags GET library/nginx | jq '.tags | map(select(. | contains(\"alpine\")))'"

  _help::item "3a. Manifest (HEAD)"

  _help::example "$name [--registry=foo] [--downgrade] [-s] manifest HEAD imagename [reference]"
  printf "%s\\n" "Examples:"
  printf "\\t%s\\n" "a. Get all info for nginx latest"
  _help::exampleindent "$name -s manifest HEAD library/nginx"
  printf "\\t%s\\n" "b. Get the digest for the 'alpine' tag of image 'nginx':"
  _help::exampleindent "$name -s manifest HEAD library/nginx alpine | jq .digest"

  _help::item "3b. Manifest (GET)"

  _help::example "$name [--registry=foo] [--downgrade] [-s] manifest GET imagename [reference]"
  printf "%s\\n" "Examples:"
  printf "\\t%s\\n" "a. Get the manifest for the latest tag of image nginx:"
  _help::exampleindent "$name -s manifest GET library/nginx"
  printf "\\t%s\\n" "b. Get the v1 manifest for the latest tag of image nginx, and extract the layers array:"
  _help::exampleindent "$name -s --registry=https://registry-1.docker.io --downgrade --disable-verification manifest GET library/nginx latest | jq .fsLayers"

  _help::item "3c. Manifest (DELETE)"

  _help::example "$name [--registry=foo] [-s] manifest DELETE imagename reference"
  printf "%s\\n" "Examples:"
  printf "\\t%s\\n" "a. Delete a tag (note: Hub doesn't support this apparently)"
  _help::exampleindent "$name -s manifest DELETE you/yourimage sometag"
  printf "\\t%s\\n" "b. Delete by digest (note: Hub doesn't support this apparently)"
  _help::exampleindent "$name -s manifest DELETE you/yourimage sha256:foobar"

  _help::item "3d. Manifest (PUT)"

  _help::example "$name [--registry=foo] [-s] manifest PUT imagename reference < file"
  printf "%s\\n" "Examples:"
  printf "\\t%s\\n" "a. Put a manifest from a file"
  _help::exampleindent "REGISTRY_USERNAME=you REGISTRY_PASSWORD=yourpass $name -s manifest PUT you/yourimage sometag < localmanifest.json"
  printf "\\t%s\\n" "b. From stdin"
  _help::exampleindent "printf \"%s\" \"Manifest content\" | REGISTRY_USERNAME=you REGISTRY_PASSWORD=yourpass $name -s manifest PUT you/yourimage sometag"
  printf "\\t%s\\n" "c. Black magic! On the fly copy from image A to B (note: this assumes all blobs are mounted already in the destination)."
  _help::exampleindent "$name -s manifest GET library/nginx latest | REGISTRY_USERNAME=you REGISTRY_PASSWORD=yourpassword $name -s manifest PUT you/yourimage sometag"
  printf "\\t%s\\n" "d. Same as c, for v1 (note: this assumes all blobs are mounted already in the destination) (note: Hub doesn't support this anymore. This is untested)."
  _help::exampleindent "$name -s --downgrade --disable-verification manifest GET library/nginx latest | REGISTRY_USERNAME=you REGISTRY_PASSWORD=yourpassword $name -s --downgrade manifest PUT you/yourimage sometag"

  _help::item "4a. Blob (HEAD)"

  _help::example "$name [--registry=foo] [-s] blob HEAD imagename reference"
  printf "%s\\n" "Examples:"
  printf "\\t%s\\n" "a. Get the final location after redirect for a blob:"
  _help::exampleindent "$name -s blob HEAD library/nginx sha256:911c6d0c7995e5d9763c1864d54fb6deccda04a55d7955123a8e22dd9d44c497 | jq .location"

  _help::item "4b. Blob (GET)"

  _help::example "$name [--registry=foo] [-s] blob GET imagename reference"
  printf "%s\\n" "Examples:"
  printf "\\t%s\\n" "a. Download a blob to a file"
  _help::exampleindent "$name -s blob GET library/nginx sha256:911c6d0c7995e5d9763c1864d54fb6deccda04a55d7955123a8e22dd9d44c497 > layer.tgz"

  _help::item "4c. Blob (MOUNT)"

  _help::example "$name [--registry=foo] [-s] blob MOUNT imagename reference origin"
  printf "%s\\n" "Examples:"
  printf "\\t%s\\n" "a. Mount a layer from nginx into image yourimage"
  _help::exampleindent "$name -s blob MOUNT you/yourimage sha256:911c6d0c7995e5d9763c1864d54fb6deccda04a55d7955123a8e22dd9d44c497 library/nginx"

  _help::item "4d. Blob (DELETE)"

  _help::example "$name [--registry=foo] [-s] blob DELETE imagename reference"
  printf "%s\\n" "Examples:"
  printf "\\t%s\\n" "a. Unmount a layer from yourimage (note: Hub doesn't support this apparently)."
  _help::exampleindent "$name -s blob DELETE you/yourimage sha256:911c6d0c7995e5d9763c1864d54fb6deccda04a55d7955123a8e22dd9d44c497"

  _help::section "Options details"

  printf "%s\\n" " > --registry=foo     Points to a specific registry address. If ommitted, will default to Docker Hub."
  printf "%s\\n" " > -s, --silent       Will not log out anything to stderr."
  printf "%s\\n" " > --help             Will display all that jazz..."

  _help::section "DANGEROUS *DANGER* options"

  printf "%s\\n" " > --downgrade            Downgrade operations from v2 to v1 manifest schema. Only has an effect when using the manifest endpoint, ignored otherwise."
  printf "%s\\n" " > --insecure             Silently ignore TLS errors."
  printf "%s\\n" " > --disable-verification Do NOT verify that payloads match their Digest, as advertised by the registry. This is DANGEROUS, and only useful for debugging, or to manipulate schema 1 on-the-fly conversions."

  _help::section "Logging and logging options"

  printf "%s\\n" "By default, all logging is sent to stderr. Options:"
  printf "\\t%s\\n" "a. Disable all logging"
  _help::exampleindent "$name -s version GET"
  printf "\\t%s\\n" "b. Enable debug logging (verbose!)"
  _help::exampleindent "REGANDER_LOG_LEVEL=true $name version GET"
  printf "\\t%s\\n" "c. Also enable authentication debugging info (this *will* LEAK authentication tokens to stderr!)"
  _help::exampleindent "REGANDER_LOG_LEVEL=true REGANDER_LOG_AUTH=true $name version GET"
  printf "\\t%s\\n" "d. Redirect all logging to /dev/null (essentially has the same result as using -s)"
  _help::exampleindent "$name version GET 2>/dev/null"
  printf "\\t%s\\n" "e. Log to a file and redirect the result of the command to a file"
  _help::exampleindent "$name version GET 2>logs.txt >version.json"

  _help::section "Non interactive authentication"

  printf "%s\\n" "You can use the REGISTRY_USERNAME and REGISTRY_PASSWORD environment variables if you want to use this non-interactively (typically if you are piping the output to something else)."
}

