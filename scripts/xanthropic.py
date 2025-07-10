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
