#!/bin/sh

echo "adding our CA and redirecting api.github.com, anthropic, and openai"
if ! curl -s -k https://localhost/ca-cert.pem > /ca.pem ; then
    echo "FAILED TO GET CA CERT"
    exit 1
fi

cat /ca.pem >> /etc/ssl/certs/ca-certificates.crt
cat /ca.pem >> `python3 -c "import certifi; print(certifi.where())"`

echo "::1 api.github.com api.openai.com api.anthropic.com" >> /etc/hosts

echo "spinning waiting for shells"
/bin/sleep inf
