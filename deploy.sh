#!/bin/sh

if [ -z "$DEPLOY_TOKEN" ] ; then
	echo "set DEPLOY_TOKEN. You can make one with: export DEPLOY_TOKEN=\$(flyctl tokens create deploy -x 24h)"
	exit 1
fi

echo "killing existing machines..."
fly m list -q | xargs -n 1 fly m destroy -f

echo "starting a new machine"
curl -X POST "https://api.machines.dev/v1/apps/proxypilot/machines" \
  -H "Authorization: Bearer $DEPLOY_TOKEN" \
  -H "Content-Type: application/json" \
  -d @machine-config.json
