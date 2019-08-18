#!/usr/bin/env bash

true
# shellcheck disable=SC2034
readonly CLI_VERSION="1.0.0"
# shellcheck disable=SC2034
readonly CLI_LICENSE="MIT License"
CLI_DESC="docker registry API shell script client"

# Init
dc::commander::initialize

# Flag valid for all operations
dc::commander::declare::flag registry "^http(s)?://.+$" "url of the registry to communicate with" optional
# XXX hook that shit in proper
dc::commander::declare::flag username "^/dev/fd/[0-9]+$" "username file descriptor" optional
dc::commander::declare::flag password "^/dev/fd/[0-9]+$" "password file descriptor" optional

case "$DC_PARGV_1" in
  blob)
    # XXX the blob API is broken
    # - the media-type for layer PUT should default to MIME_OCI_LAYER and be a --type flag
    CLI_DESC="The blob endpoint allows you to retrieve (HEAD and GET) and modify (DELETE, PUT, MOUNT) blobs."

    dc::commander::declare::flag no-shasum "^$" "disable shasum verification of blobs (DANGER)" optional
    dc::commander::declare::flag from "$GRAMMAR_NAME" "when blob mounting, origin image name" optional

    dc::commander::declare::arg 1 "^blob$" "\"blob\"" "the blob endpoint"
    dc::commander::declare::arg 2 "^HEAD|GET|PUT|DELETE|MOUNT$" "method" "method to use (HEAD, GET, PUT, DELETE, MOUNT)"
    dc::commander::declare::arg 3 "$GRAMMAR_NAME" "name" "image name, like: library/nginx"

    # $GRAMMAR_TAG_DIGEST
    dc::commander::declare::arg 4 ".+" "reference" "tag name or digest (for GET/HEAD/DELETE/MOUNT), or media-type (for PUT)" optional

    CLI_EXAMPLES="Get the final location (after redirect) for a blob:
> regander -s blob HEAD library/nginx sha256:911c6d0c7995e5d9763c1864d54fb6deccda04a55d7955123a8e22dd9d44c497 | jq .location

Download a blob to a file:
> regander -s blob GET library/nginx sha256:911c6d0c7995e5d9763c1864d54fb6deccda04a55d7955123a8e22dd9d44c497 > layer.tgz

Mount a layer from 'nginx' into image 'yourimage':
> regander -s --from=library/nginx blob MOUNT you/yourimage sha256:911c6d0c7995e5d9763c1864d54fb6deccda04a55d7955123a8e22dd9d44c497

Unmount a layer from yourimage (note: Hub doesn't support this apparently):
> regander -s blob DELETE you/yourimage sha256:911c6d0c7995e5d9763c1864d54fb6deccda04a55d7955123a8e22dd9d44c497

Upload an OCI layer from a file:
> regander -s blob PUT you/yourimage $MIME_OCI_LAYER < layer.tgz
"
    ;;

  ###################### MANIFEST
  manifest)
    CLI_DESC="The manifest endpoint allows you to retrieve (HEAD and GET) and modify (DELETE and PUT) manifests.

The PUT method expect input on stdin.
Schema 2 and OCI are supported (included manifest lists).
Schema 1 is supported (through the use of --downgrade) albeit not heavily tested (and its use is discouraged).
Note that some registries do not implement DELETE."

    dc::commander::declare::flag no-shasum "^$" "disable shasum verification of manifests (DANGER)" optional
    dc::commander::declare::flag downgrade "^$" "downgrade to schema 1 version (LEGACY)" optional

    dc::commander::declare::arg 1 "^manifest$" "\"manifest\"" "the manifest endpoint"

    dc::commander::declare::arg 2 "^HEAD|GET|PUT|DELETE$" "method" "method to use (HEAD, GET, PUT, DELETE)"
    dc::commander::declare::arg 3 "$GRAMMAR_NAME" "name" "image name, example: library/nginx"
    dc::commander::declare::arg 4 "$GRAMMAR_TAG_DIGEST" "reference" "tag name or digest (default to latest if not specified)" optional

    CLI_EXAMPLES="Get all info for nginx latest:
> regander -s manifest HEAD library/nginx

Get the digest for the 'alpine' tag of image 'nginx':
> regander -s manifest HEAD library/nginx alpine | jq .digest

Get the manifest for the latest tag of image nginx:
> regander -s manifest GET library/nginx

Get the v1 manifest for the latest tag of image nginx, and extract the layers array:
> regander -s --registry=https://registry-1.docker.io --downgrade --no-shasum manifest GET library/nginx latest | jq .fsLayers

Delete a tag (note: Hub doesn't support this apparently):
> regander -s manifest DELETE you/yourimage sometag

Delete by digest (note: Hub doesn't support this apparently):
> regander -s manifest DELETE you/yourimage sha256:foobar

Put a manifest from a file:
> REGISTRY_USERNAME=you REGISTRY_PASSWORD=yourpass regander -s manifest PUT you/yourimage sometag < localmanifest.json

Pipe a manifest:
> printf \"%s\" \"Manifest content\" | REGISTRY_USERNAME=you REGISTRY_PASSWORD=yourpass regander -s manifest PUT you/yourimage sometag

On the fly copy from image A to B:
> regander -s manifest GET library/nginx latest | REGISTRY_USERNAME=you REGISTRY_PASSWORD=yourpassword regander -s manifest PUT you/yourimage sometag

Same as above, for v1 (note: Hub doesn't support this anymore, so, this is untested):
> regander -s --downgrade --no-shasum manifest GET library/nginx latest | REGISTRY_USERNAME=you REGISTRY_PASSWORD=yourpassword regander -s --downgrade manifest PUT you/yourimage sometag
"
    ;;

  ###################### TAGS
  tags)
    CLI_DESC="The tags endpoint returns a list of all tags for a given image."

    dc::commander::declare::arg 1 "^tags$" "\"tags\"" "the tags endpoint"
    dc::commander::declare::arg 2 "^GET$" "\"GET\"" "this endpoint only supports GET"
    dc::commander::declare::arg 3 "$GRAMMAR_NAME" "name" "image name, like: library/nginx"

    CLI_EXAMPLES="Get all tags for the official nginx image:
> regander -s tags GET library/nginx

    Same, but filter out only the tags containing 'alpine' in their name:
> regander -s tags GET library/nginx | jq '.tags | map(select(. | contains(\"alpine\")))'
    "
    ;;

  ###################### CATALOG
  catalog)
    CLI_DESC="The catalog endpoint returns a catalog of images on that registry.

There is no parameters or arguments to this method, which only supports GET.
Note that many (most?) registries do not implement this endpoint."

    dc::commander::declare::arg 1 "^catalog$" "\"catalog\"" "the catalog endpoint"
    ;;

  ###################### VERSION
  version)
    CLI_DESC="The version endpoint returns the protocol version implemented by that registry.

This endpoint mostly serves as a way to verify that you are actually talking to a registry.
There is no parameters or arguments to this method, which only supports GET."

    CLI_EXAMPLES="Get the Hub protocol version, interactively asking for credentials:
> regander -s version

Get the protocol version from registry-1.docker.io using anonymous and pipe it to jq:
> regander -s --registry=https://registry-1.docker.io version | jq
"

    dc::commander::declare::arg 1 "^version$" "\"version\"" "the version endpoint"
    ;;

  ###################### DEFAULT
  *)
    dc::commander::declare::arg 1 "^blob|manifest|tags|catalog|version$" "endpoint" "what to hit (blob, manifest, tags, catalog, version)"
    CLI_EXAMPLES="regander will interactively ask for credentials when necessary. You can also specify your credentials using the following environment variables:
> REGISTRY_USERNAME
> REGISTRY_PASSWORD

by default, all logging goes to stderr, and stdout is used solely for payload output. Here is a typical way to redirect logs to a file, and the payload response to another
> regander version GET 2>logs.txt >version.json

see the per-endpoint help for more examples and information
> regander --help manifest
> regander --help blob
> regander --help version
> regander --help catalog
> regander --help tags
"
    ;;
esac

# Boot
dc::commander::boot

# Requirements
dc::require jq

# Further argument validation
if [ ${#DC_PARGV_3} -ge 256 ]; then
  dc::logger::error "Image name $DC_PARGV_3 is too long"
  exit "$ERROR_ARGUMENT_INVALID"
fi

if [ ${#DC_ARGV_FROM} -ge 256 ]; then
  dc::logger::error "Source image name $DC_ARGV_FROM is too long"
  exit "$ERROR_ARGUMENT_INVALID"
fi


# Build the registry url, possibly honoring the --registry variable
# shellcheck disable=SC2034
readonly REGANDER_REGISTRY="${DC_ARGV_REGISTRY:-${REGANDER_DEFAULT_REGISTRY}}/v2"

# Build the UA string
# -${DC_BUILD_DATE} <- too much noise
# shellcheck disable=SC2034
readonly REGANDER_UA="${DC_CLI_NAME}/${CLI_VERSION} dubocore/${DC_VERSION}-${DC_REVISION} (bash ${DC_DEPENDENCIES_V_BASH}; jq ${DC_DEPENDENCIES_V_JQ}; $(uname -mrs))"

# If --downgrade is passed, change the accept header
if [ "${DC_ARGE_DOWNGRADE}" ]; then
  REGANDER_ACCEPT=(
    "$MIME_V1_MANIFEST"
    "$MIME_V1_MANIFEST_JSON"
    "$MIME_V1_MANIFEST_SIGNED"
  )
else
  REGANDER_ACCEPT=(
    "$MIME_V2_MANIFEST"
    "$MIME_V2_LIST"
    "$MIME_OCI_MANIFEST"
    "$MIME_OCI_LIST"
  )
fi

# Map credentials to the internal variable
# XXX finish hooking that shit up properly
export REGANDER_USERNAME="${REGISTRY_USERNAME}"
export REGANDER_PASSWORD="${REGISTRY_PASSWORD}"
if [ "$DC_ARGV_USERNAME" ]; then
  REGANDER_USERNAME="$(cat "$DC_ARGV_USERNAME")"
  REGANDER_PASSWORD="$(cat "$DC_ARGV_PASSWORD")"
fi

# Seal it
# shellcheck disable=SC2034
readonly REGANDER_ACCEPT
# shellcheck disable=SC2034
readonly REGANDER_NO_VERIFY=${DC_ARGE_DISABLE_VERIFICATION}
# shellcheck disable=SC2034
readonly CLI_EXAMPLES
# shellcheck disable=SC2034
readonly CLI_DESC

# Call the corresponding method
if ! regander::"$(echo "$DC_PARGV_1" | tr '[:upper:]' '[:lower:]')"::"$(echo "${DC_PARGV_2:-GET}" | tr '[:lower:]' '[:upper:]')" "$DC_PARGV_3" "$DC_PARGV_4" "$DC_ARGV_FROM"; then
  dc::logger::error "The requested endpoint ($DC_PARGV_1) and method (${DC_PARGV_2:-GET}) doesn't exist in the registry specification or is not supported by regander."
  exit "$ERROR_ARGUMENT_INVALID"
fi
