
# Setup

Generate a CA. This isnt done automatically during docker builds.

* `git clone git@github.com:timflyio/tlsproxy.git`
* `cd tlsproxy; go run main.go ca`

Build the images

* `fly deploy --build-only --image-label shell -c fly.toml.shell`
* `fly deploy --build-only --image-label sideproxy -c fly.toml.sideproxy`

Run a machine with the two containers specified in cli-config.json.

* `fly m run --machine-config cli-config.json --vm-cpu-kind shared --vm-cpus 1 --vm-memory 256 -r qmx`
