# Reghigh

> Shell-script images manipulation

Reghigh allows you to easily manipulate images (both standalone and multi-architecture) stored in a Docker registry.

Unlike `regander`, it does not expose API level concepts but rather user-centric operations (like clone, download).

It also serves as a good example of what you can do on top of `regander`.

## Usage TL;DR

```
[ENV=FOO] reghigh [flags] command imagename [reference]
```

For example:

```
reghigh -s info library/nginx
reghigh -s download library/nginx
reghigh -s --unpack --path=./local-folder download library/nginx sha256:b1fec83e1ab7b54a52daef6ba17f95c6389702d6841f8463945d78c8a69ed3fe
```

