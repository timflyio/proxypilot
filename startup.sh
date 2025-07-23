#!/bin/sh

while [ ! -s /ca.pem ] ; do
    echo "fetching CA"
    if ! curl -s -k https://localhost/ca-cert.pem > /ca.pem ; then
        echo "FAILED TO GET CA CERT"
        sleep 1
    fi
done

echo "adding our CA and redirecting api.github.com, anthropic, and openai"
cat /ca.pem >> /etc/ssl/certs/ca-certificates.crt
cat /ca.pem >> `python3 -c "import certifi; print(certifi.where())"`

echo "127.0.0.1 api.github.com api.openai.com api.anthropic.com" >> /etc/hosts

echo "spinning waiting for shells"
/bin/sleep inf
