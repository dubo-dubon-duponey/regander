# Hacking regander and reghigh

## TL;DR

Hack in the `source` folder.

```
# Building the binaries
make build

# Syntax
make lint

# Tests
make test

```

## Test in containers

Use [dckr](https://github.com/dubo-dubon-duponey/dckr).

On mac, `brew install dubo-dubon-duponey/brews/dckr`

Then just run any of the make commands with `dckr`.

Specifically:
```
DOCKERFILE=./sh-art/Dockerfile
for TARGET in ubuntu-lts-current ubuntu-next debian-current debian-next; do
  dckr make test
done
```

## Spirit

 * bash correctness (but not POSIX-ness)
 * light on dependency (shasum, and the base dc library)
 * standalone script
 * modular, simple to hack-on source code
 * DRY, KISS implementation of the registry REST API
 * additional, more advanced scenarios, should be composed on top of `regander` (see `reghigh` as a good example), not added as core features
