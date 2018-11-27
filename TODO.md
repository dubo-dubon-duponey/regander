# TODO

 * support basic auth
 * support DTR token auth?
 * OSX keychain integration -> core
 * Byte-range blob fetch
 * resumable upload
 * consume and present error payloads as returned by the registry
 * bash auto-completion
 * notary?

# Everything that is wrong

 * nginx in Hub and DTR are "validating" names, effectively overriding registry responses in some cases
 * garant doesn't support multi-scopes in a single scope GET parameter: you have to repeat the scope GET param multiple param
 * on an empty image, for tags GET:
  * Hub returns a 404
  * DTR returns a 200 with a [] body
  * OSS registry likely behaves as the Hub
 * rewrite to schema v1 seems busted in DTR
 * DTR (and also Hub, differently) does pre-validate image / tag names, returning different errors at the nginx level
 * registry will 500 on an empty blob
 * upload endpoint with POST will always return a redirect, regardless of whether it's on a redirected upload endpoint already
 * blob MOUNT final location contains FQDN, blob HEAD is relative
