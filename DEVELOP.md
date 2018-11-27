  # Hacking regander

## TL;DR

Hack in the `source` folder.

```
# Building the binaries
make build

# Syntax
make lint

# Unit tests
make unit

# Integration tests
make integration
```

## Spirit

 * bash correctness (but not POSIX-ness)
 * light on dependency (shasum, and the base dc library)
 * standalone script
 * modular, simple to hack-on source code
 * DRY, KISS implementation of the registry REST API
 * additional, more advanced scenarios, should be composed on top of `regander` (see `reghigh`), not added as core features
