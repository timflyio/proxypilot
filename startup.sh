#!/bin/sh

echo "adding our CA and redirecting api.github.com"
sleep 2 # XXX replace this with a health check configured in pilot for waiting for the sidecar to be ready
if ! curl -s -k https://localhost/ca-cert.pem > /ca.pem ; then
    echo "FAILED TO GET CA CERT"
    exit 1
fi

cat /ca.pem >> /etc/ssl/certs/ca-certificates.crt
cat /ca.pem >> `python3 -c "import certifi; print(certifi.where())"`

echo "::1 api.github.com api.openai.com api.anthropic.com" >> /etc/hosts

echo "spinning waiting for shells"
/bin/sleep inf
