#!/bin/sh

echo "adding our CA and redirecting api.github.com"
cat /ca.pem >> /etc/ssl/certs/ca-certificates.crt
echo "::1 api.github.com" >> /etc/hosts

echo "spinning waiting for shells"
/bin/sleep inf
