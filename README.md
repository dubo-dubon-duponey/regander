# Regander

> A piece of shcript to interact with them Dockeristries

Regander is a full-fledged client for the [Docker Registry API](https://docs.docker.com/registry/spec/api/) aiming at completeness and correctness.

In a shell: it takes care of the dreaded token authentication and all the HTTP monkeying for you, allowing the consumer 
to easily implement higher-level scripts to manipulate images, by using simple method calls that closely mimic the API.

Regander also provides extensive debugging and logging options that are useful to troubleshoot misbehaving registries and images,
including `curl` stances that can be copy-pasted to manually replay HTTP calls, and uses exit codes to convey meaningful errors.

A set of additional scripts in the `examples` folder are provided for fun (and profit), demonstrating
these "high-level" image manipulation methods (eg: downloading and uploading a multi-architecture image, 
copying an image over between registries, etc).

## Installation

### The easy-way

> on mac

`brew install dubo-dubon-duponey/brews/regander`

### The other way

> linux and mac

You need `bash` (the real bash, reasonably recent - you have that, right?)

And `jq` (on mac `brew install jq`).

Then `git clone https://github.com/dubo-dubon-duponey/regander --recursive`.

Then `make` inside the clone.

Now you have `./bin/regander`

### Windows

> meh

`meh`

## Usage TL;DR

```
[ENV=FOO] regander [flags] endpoint METHOD [object] [reference] [origin-object]
```

For example:

```
regander -s --registry=https://myregistry manifest HEAD library/nginx alpine
```

Moar?

```
regander --help
```

The user will be prompted for credentials in interactive mode.
Otherwise regander will fallback to anonymous queries, or use whatever credentials are provided through the environment.

See the [reference](REFERENCE.md) for extensive usage details.

## Examples

Look into the examples folder for:

1. `examples/clone-image.sh`: take an image and clone it into another image on the same registry using blob mounts commands

2. `examples/download-image.sh`: download an entire image locally and unpack its content

## Caveats and TODO

See the [todo](TODO.md).

## Develop

See the [develop](DEVELOP.md) doc.
