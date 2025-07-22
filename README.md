
# Setup

Make the app. Give it access to `tokenizer.flycast`.
This can work without direct access to tokenizer via flycast, using `tokenizer.fly.io`,
but flycast is required if we want to lock down a sealed secret to a specific app.

* `fly app create proxypilot -o personal`
* `fly -a tokenizer ips allocate-v6 --private --org personal`

Seal secrets and set them for the app. The `wrap.sh` script does this, provided you have
the `SEAL_KEY` for the tokenizer, and values for tokens in the `ANTHROPIC_API_KEY`,
`OPENAI_API_KEY`, and `GH_TOKEN`.

* `./wrap.sh`

Now build the docker image:

* `fly deploy --build-only --image-label shell --push`

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

In the sideproxy container you can access the sealed github token, but it does not have access
to the actual github token being used:

* `fly ssh console --container sideproxy`
* `echo $GH_TOKEN`


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
which only allow access to `https://api.github.com`, and only works from the proxyauth app (using fly-src auth),
unsealing the github token into an authorization header. It proxies this request to the `http://api.github.com`
with the authorization header.

## Example

This example demonstrates how dummy tokens are automatically replaced when making
requests to anthropic, github, and openai:

```
$ fly ssh console --container shell
Connecting to fdaa:9:1094:a7b:4ce:9c8:c214:2... complete
root@shell:/# cd
root@shell:~# env |egrep 'TOKEN|KEY'
ANTHROPIC_API_KEY=dummy
OPENAI_API_KEY=dummy
GH_TOKEN=dummy
root@shell:~# cat anthropic.sh 
#!/bin/sh

curl https://api.anthropic.com/v1/messages \
     --header "x-api-key: $ANTHROPIC_API_KEY" \
     --header "anthropic-version: 2023-06-01" \
     --header "content-type: application/json" \
     --data \
'{
    "model": "claude-opus-4-20250514",
    "max_tokens": 1024,
    "messages": [
        {"role": "user", "content": "Hello, world"}
    ]
}'
root@shell:~# ./anthropic.sh 
{"id":"msg_0197HHPbR13ALq22Ea6PWHzF","type":"message","role":"assistant","model":"claude-opus-4-20250514","content":[{"type":"text","text":"Hello! Welcome to our conversation. How are you doing today? Is there anything specific you'd like to talk about or any questions I can help you with?"}],"stop_reason":"end_turn","stop_sequence":null,"usage":{"input_tokens":10,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":35,"service_tier":"standard"}}
root@shell:~# cat anthropic.mjs
import Anthropic from '@anthropic-ai/sdk';

const anthropic = new Anthropic({
  apiKey: 'my_api_key', // defaults to process.env["ANTHROPIC_API_KEY"]
});

const msg = await anthropic.messages.create({
  model: "claude-opus-4-20250514",
  max_tokens: 1024,
  messages: [{ role: "user", content: "Hello, Claude" }],
});
console.log(msg);
root@shell:~# node anthropic.mjs
{
  id: 'msg_01JX4bu4uzef1wtKNqFUJ6Qj',
  type: 'message',
  role: 'assistant',
  model: 'claude-opus-4-20250514',
  content: [
    {
      type: 'text',
      text: "Hello! It's nice to meet you. How are you doing today?"
    }
  ],
  stop_reason: 'end_turn',
  stop_sequence: null,
  usage: {
    input_tokens: 10,
    cache_creation_input_tokens: 0,
    cache_read_input_tokens: 0,
    output_tokens: 18,
    service_tier: 'standard'
  }
}
root@shell:~# cat xanthropic.py 
#!/usr/bin/env python3

import anthropic

client = anthropic.Anthropic() # uses os.environ.get("ANTHROPIC_API_KEY")
message = client.messages.create(
    model="claude-opus-4-20250514",
    max_tokens=1024,
    messages=[
        {"role": "user", "content": "Hello, Claude"}
    ]
)
print(message.content)
root@shell:~# ./xanthropic.py        
[TextBlock(citations=None, text="Hello! It's nice to meet you. How are you doing today?", type='text')]
root@shell:~# gh auth status
github.com
  ✓ Logged in to github.com account timflyio (GH_TOKEN)
  - Active account: true
  - Git operations protocol: https
  - Token: *****
root@shell:~# cat openai.sh
#!/bin/sh

curl https://api.openai.com/v1/responses \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -d '{
    	"model": "gpt-4o-mini",
        "input": "Write a one-sentence bedtime story about a unicorn."
    }'
root@shell:~# ./openai.sh
{
  "id": "resp_68702bbe11c08194a0b85f89e23a817a005703628be936ce",
  "object": "response",
  "created_at": 1752181694,
  "status": "completed",
  "background": false,
  "error": null,
  "incomplete_details": null,
  "instructions": null,
  "max_output_tokens": null,
  "max_tool_calls": null,
  "model": "gpt-4o-mini-2024-07-18",
  "output": [
    {
      "id": "msg_68702bbe72548194b80bea23f850f2bd005703628be936ce",
      "type": "message",
      "status": "completed",
      "content": [
        {
          "type": "output_text",
          "annotations": [],
          "logprobs": [],
          "text": "As the silvery moon cast a gentle glow over the enchanted meadow, the brave little unicorn spread her shimmering wings and soared into the starry sky, making wishes come true for all the children asleep below."
        }
      ],
      "role": "assistant"
    }
  ],
  "parallel_tool_calls": true,
  "previous_response_id": null,
  "reasoning": {
    "effort": null,
    "summary": null
  },
  "service_tier": "default",
  "store": true,
  "temperature": 1.0,
  "text": {
    "format": {
      "type": "text"
    }
  },
  "tool_choice": "auto",
  "tools": [],
  "top_logprobs": 0,
  "top_p": 1.0,
  "truncation": "disabled",
  "usage": {
    "input_tokens": 18,
    "input_tokens_details": {
      "cached_tokens": 0
    },
    "output_tokens": 42,
    "output_tokens_details": {
      "reasoning_tokens": 0
    },
    "total_tokens": 60
  },
  "user": null,
  "metadata": {}
}
root@shell:~# cat xopenai.py 
#!/usr/bin/env python3

from openai import OpenAI
client = OpenAI()

response = client.responses.create(
    model="gpt-4o-mini",
    input="Write a one-sentence bedtime story about a unicorn."
)

print(response.output_text)
root@shell:~# ./xopenai.py
As the moonlight danced upon the meadow, a gentle unicorn named Lila spread her shimmering wings and soared into the starry sky, leaving a trail of dreams for children everywhere to follow as they drifted off to sleep.
root@shell:~# cat openai.mjs
import OpenAI from "openai";
const client = new OpenAI();

const response = await client.responses.create({
    model: "gpt-4.1",
    input: "Write a one-sentence bedtime story about a unicorn.",
});

console.log(response.output_text);
root@shell:~# node openai.mjs
Under a sky sprinkled with twinkling stars, a gentle unicorn named Lila danced through a field of glowing moonflowers, carrying sweet dreams to every sleeping child.
root@shell:~# exit
```

## Notes

* This requires access to tokenizer via flycast in order to use tokenizer and in order to do fly-src auth, locking down the secret to a single org/app. If we were to use this technique more widely we might want to consider a way to make tokenizer globally reachable via flycast without having to configure each target org. NOTE: proxy might support adding fly-src headers to normal requests in the future.
* If we wanted to automate this more, we seal tokens on behalf of users at deploy time, and lock down the sealed token to a specific org/app/machine id, so that the token couldn't even be moved to another machine in the same app.
* The `URLAUTH` is exposed to all containers via the new `/.fly/api` secrets endpoints. ie. `curl --unix-socket /.fly/api "http://flaps/v1/apps/$FLY_APP_NAME/secrets?show_secrets=1"`.  This has implications to any container that is trying to limit secrets access!
