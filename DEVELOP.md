  # Hacking regander

## TL;DR

Hack in the `source` folder.

```
# Syntax
make lint

# Unit tests
make unit

# Integration tests
make integration

# Building the final regander binary
make build
```

## Spirit

 * bash correctness (but not POSIX-ness)
 * light on dependency (bash3, jq, shasum, and the base dc library)
 * standalone script (yes, that's 2000+ lines)
 * modular, simple to hack on source code
 * DRY, KISS implementation of the registry REST API
 * additional, more advanced scenarios, should be composed on top of `regander`, not added as core features
