# Regander
[![FOSSA Status](https://app.fossa.io/api/projects/git%2Bgithub.com%2Fdubo-dubon-duponey%2Fregander.svg?type=shield)](https://app.fossa.io/projects/git%2Bgithub.com%2Fdubo-dubon-duponey%2Fregander?ref=badge_shield)


> A piece of shcript to interact with docker registries

Regander is a full-fledged REST client for the [Docker Registry API](https://docs.docker.com/registry/spec/api/) aiming at completeness.

In a shell: it takes care of the dreaded token authentication and all the HTTP monkeying for you, allowing the consumer 
to easily implement higher-level methods to manipulate images, by using simple method calls that closely mimic the API expressiveness.

Regander also provides verbose debugging and logging options that are useful to troubleshoot misbehaving registries and images,
including `curl` stances that can be copy-pasted to manually replay HTTP calls.

A set of additional scripts (named `regander.$$$$$.sh`) are provided for fun (and profit), demonstrating
implementation of some of these "higher-level" image manipulation technics (completely downloading a multi-architecture image, 
cloning an image, pushing an image, etc).

## Requirements

`bash` and `jq`.

On mac: `brew install jq`

On linux: left as an exercise to the reader.

On windows: duh.

## Installation

Copy the `regander` shell script, make it executable, and put it in your PATH.

Alternatively, clone this repo to also get the additional scripts (and put them all in your PATH).

## How-to use

```
regander [options] endpoint METHOD [object] [reference] [origin-object]
```

For example:

```
regander -s --downgrade=true manifest HEAD library/nginx alpine
```

Try `regander --help` for everything else...

## TL;DR / cheat sheet

Reading:

```
export REGISTRY_USERNAME=anonymous

regander -s --registry=https://registry-1.docker.io version GET

regander -s --registry=https://registry-1.docker.io tags GET library/nginx

regander -s --registry=https://registry-1.docker.io manifest HEAD library/nginx alpine

regander -s --registry=https://registry-1.docker.io manifest GET library/nginx alpine

regander -s --registry=https://registry-1.docker.io blob GET library/nginx 
```

## Examples

Look into the examples folder for:

1. `example.clone.sh`: take an image and clone it into another image using blob mounts on the same registry

2. ``: analyze an image by getting its total size and number of layers

3. `example.download.sh`: downloading an image locally, verifying it, and unpacking its content

## Caveats and TODO

Not supported:
 * Registries with basic authentication. Only token auth is implemented.
 * Resumable upload
 * Byte-range blob fetch
 * Manifest list
 * OSX keychain integration

## Spirit

Regander itself is copy-pastable, and should stay that way - it's a standalone binary, with no crazy dependency, or complex installation.

Yeah, that's 800+ lines.


## License
[![FOSSA Status](https://app.fossa.io/api/projects/git%2Bgithub.com%2Fdubo-dubon-duponey%2Fregander.svg?type=large)](https://app.fossa.io/projects/git%2Bgithub.com%2Fdubo-dubon-duponey%2Fregander?ref=badge_large)