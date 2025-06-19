
# Setup

Generate a CA. This isnt done automatically during docker builds.

* `git clone git@github.com:timflyio/tlsproxy.git`
* `cd tlsproxy; go run main.go ca`

Make the app and set the sealed secret. Give it access to `tokenizer.flycast`.
This can work without direct access to tokenizer via flycast, using `tokenizer.fly.io`,
but flycast is required if we want to lock down a sealed secret to a specific app.

* `fly app create proxypilot -o personal`
* `fly secrets set --stage URLAUTH=sealed-github-token-here`
* `fly -a tokenizer ips allocate-v6 --private --org personal`

Build the images

* `fly deploy --build-only --image-label shell -c fly.toml.shell --push`
* `fly deploy --build-only --image-label sideproxy -c fly.toml.sideproxy --push`

Run a machine with the two containers specified in cli-config.json.
This doesnt work:

* `fly m run --machine-config cli-config.json --vm-cpu-kind shared --vm-cpus 1 --vm-memory 256 -r qmx`

But using the API does work. Instead use `deploy.sh`. You'll need a token in `DEPLOY_TOKEN`.

* `./deploy.sh`

Try it out. From the shell container you can use `gh`, but you have no access to the real github token,
or acces to the injected CA key.  Go ahead and search the filesystem for it.

* `fly ssh console --container shell`
* `echo $GH_TOKEN`
* `gh auth status`

In the sideproxy container you can access the github token:

* `fly ssh console --container sideproxy`
* `echo $URLAUTH`


Destroy it

* `fly m list`
* `fly m destroy --force <machine-id-here>`

## How it works

This builds two containers in a machine. The first is a shell in the `shell` container. It has the `gh` binary
and the `GH_TOKEN` set to a dummy value.
The shell has an `/etc/hosts` entry associating `api.github.com` with `::1`. Requests to `https://api.github.com` will be
sent there, and received by the side proxy's listener.

The second container is the `sideproxy` container which is listening on `::1` port 443. It auto-generates
TLS certificates based on the request's SNI, using its own CA. The `shell` container is configured to trust
this CA.  To process a request, the server uses the `https://tokenizer.fly.io` proxy, passing in the
sealed secret token, which is encrypted/sealed to the tokenizers public key.
The tokenizer receives the sealed secret, and extracts its rules,
which only allow access to `https://api.github.com`, requiring an auth header on the proxy request, and
unsealing the github token into an authorization header. It proxies this request to the `http://api.github.com`
with the authorization header.

## Sealed secrets

To seal the secret, I'm using the following script. Pick an arbitrary `AUTH_TOKEN` and use as the `PROXYAUTH` in
the `machine-config.json` env var. Set the `SEAL_KEY` to the public key from `tokenizer.fly.io` (it prints it in
its logs during startup). Set `TOKEN` to the `GH_TOKEN` you want to seal.  Take the resulting base64 string
and put it into `machine-config.json` as the `URLAUTH` value.

```
#!/usr/bin/env ruby

require 'base64'
require 'digest'
require 'json'
require 'rbnacl'

auth_key = ENV["AUTH_TOKEN"]
seal_key = ENV["SEAL_KEY"]
token = ENV["TOKEN"]
secret = {
    inject_processor: {
        token: token
    },
    fly_src_auth: {
        allowed_orgs: ["tim-newsham"],
        allowed_apps: ["proxypilot"],
    },
    allowed_hosts: ["api.github.com"],
}
}

seal_key = [seal_key].pack('H*')
sealed_secret = RbNaCl::Boxes::Sealed.new(seal_key).box(secret.to_json)
b64 = Base64.encode64(sealed_secret).delete("\n")

puts(token)
puts(auth_key)
puts(b64)
```


## Notes

The sidecar only has access to a sealed github key, but anyone with access to the sealed github
key can use it to make requests through the public tokenizer endpoint. 
We should allow flycast access to this app, and seal the key with a FlySrc restriction saying the
key can only be used by this app. Then the sealed key could only be used from within this app
if it was ever compromised.
