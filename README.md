
# Setup

Generate a CA. This isnt done automatically during docker builds.

* `git clone git@github.com:timflyio/tlsproxy.git`
* `cd tlsproxy; go run main.go ca`

Make the app and set the GH token:

* `fly app create proxypilot`
* `fly secrets set --stage TOKEN=<github-token-here>`

Build the images

* `fly deploy --build-only --image-label shell -c fly.toml.shell --push`
* `fly deploy --build-only --image-label sideproxy -c fly.toml.sideproxy --push`

Run a machine with the two containers specified in cli-config.json.
This doesnt work:

* `fly m run --machine-config cli-config.json --vm-cpu-kind shared --vm-cpus 1 --vm-memory 256 -r qmx`

But using the API does work. You'll need a token in `DEPLOY_TOKEN`.

* `./deploy.sh`

Try it out. From the shell container you can use `gh`, but you have no access to the real github token,
or acces to the injected CA key.  Go ahead and search the filesystem for it.

* `fly ssh console --container shell`
* `echo $GH_TOKEN`
* `gh auth status`

In the sideproxy container you can access the github token:

* `fly ssh console --container sideproxy`
* `echo $TOKEN`


Destroy it

* `fly m list`
* `fly m destroy --force <machine-id-here>`



## Notes

The proxy is using a hardwired IP address for `api.github.com`. This is brittle.
It doesn't have to since its running in its own container without a hacked up /etc/hosts.

The proxy has access to the github token. In the future it should just proxy to a tokenizer proxy that has
access to secrets that machines do not have access to.
