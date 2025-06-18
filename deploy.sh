#!/bin/sh

if [ -z "$DEPLOY_TOKEN" ] ; then
	echo "set DEPLOY_TOKEN"
	exit 1
fi

curl -X POST "https://api.machines.dev/v1/apps/proxypilot/machines" \
  -H "Authorization: Bearer $DEPLOY_TOKEN" \
  -H "Content-Type: application/json" \
  -d @machine-config.json
