#!/usr/bin/env bash

if [ -z "$SEAL_KEY" ] ; then
	echo "you must have SEAL_KEY set"
	exit 1
fi

ORG=tim-newsham
APP=proxypilot

(cd tlsproxy && go build -o ../seal ./seal.go) || exit 1
fly secrets set --stage \
	"ANTHROPIC_API_KEY=$(./seal -org $ORG -app $APP -host api.anthropic.com -header x-api-key $ANTHROPIC_API_KEY)" \
	"OPENAI_API_KEY=$(./seal -org $ORG -app $APP -host api.openai.com $OPENAI_API_KEY)" \
	"GH_TOKEN=$(./seal -org $ORG -app $APP -host api.github.com $GH_TOKEN)"
echo "done"

