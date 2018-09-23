# Reference

## Invocation

```
[ENV=FOO] regander [flags] endpoint METHOD [object] [reference] [origin-object]
```

## Environment variables

`regander` recognizes two environment variables: `REGISTRY_USERNAME` and `REGISTRY_PASSWORD` that let
you pass credentials non-interactively.

See "logging" for more on controlling output.

## Flags

The following flags can be used in combination with an actual `regander` method call:

```
-s, --silent
    Will not log anything to stderr

--insecure
    Silently ignore TLS errors (see curl --insecure for more)

--registry=scheme://host[:port]
    Points regander to the registry at scheme://host[:port]
    Supported schemes are http and https
    Any hostname that curl understands can be used
    If not specified, regander will default to Docker Hub

--downgrade
    Force regander to behave as a schema v1 client (this will hurt your feelings!)
```

The following flags are standalone commands:

```
--version
    Output regander version and exit

--help
    Print out regander help

```

## Endpoints and methods reference

The following is currently implemented:

```
regander version GET
regander catalog GET
regander tags GET image
regander manifest HEAD image
regander manifest GET image
regander manifest PUT image
regander manifest DELETE image
regander blob HEAD image ref
regander blob GET image ref
regander blob MOUNT destination-image object-reference from-source-image
regander blob PUT image ref
regander blob DELETE image ref
```

## Exit codes

`regander` uses exit codes to convey information about specific error conditions it encounters.

These exit codes and their meaning can be seen in `sh-art` and in the source tree, in the `errors.sh` files (look for ERROR_* constants).

```
# System errors
200   network level error (eg: curl exiting abnormally)
201   an argument is missing to one of your commands
202   an argument does not pass validation
203   operation is not supported
204   generic error
205   filesystem error
206   you miss jq, shasum or bash

## Registry errors
12    malformed request
13    unauthorized
14    not found
15    registry does not support operation
16    registry says you are making too many requests
17    registry is foobared (5-hundreded)
20    unknown registry error
30    not a compatible registry
31    shasum verification failed
```

Typically, if you are scripting `regander`, you should check the exit code before processing the output.

Example:

```
manifest=$(regander -s --registry=thiswillnotwork manifest GET library/nginx)
ex=$?
if [[ $ex != 0 ]]; then
  echo "Failed! Exit code was $ex"
fi
```

## Logging

`regander` logs to stderr, at the `info` level by default.

This behavior can be altered in two ways:

 * by specifying the `REGANDER_LOG_LEVEL` environment variable to another level
 * by using the `-s` flag which will entirely mute all logging, including errors, and will override the environment variable

By default, credentials and other authentication tokens are redacted. If you want them to appear 
(for example, in `curl` statements), set `REGANDER_LOG_AUTH=true`.

Finally note that logging in `debug` WILL likely leak sensitive information regardless.

```
# Log levels

REGANDER_LOG_LEVEL=debug
    Maximum verbosity, including full curl output.
    You typically do NOT need this unless you are hacking on regander itself.
    This WILL LEAK SENSITIVE information.

REGANDER_LOG_LEVEL=info
    Default level.
    This will output thorough information about network transactions.
    
REGANDER_LOG_LEVEL=warning
    Will typically only print out important messages.
    Recommended for well tested production use, but will possibly be terse to debug.
    
REGANDER_LOG_LEVEL=error
    Only fatal error conditions.


# Other environment variables controlling logs

REGANDER_LOG_AUTH=true
    Will NOT redact credentials and auth tokens.
    
TERM=
    Will forcefully suppress colors on the log output.
```

Example, logging only warnings and errors into a file:

```
LOG_LEVEL=warning regander version GET 2> test.log
```
