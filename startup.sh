#!/bin/sh

echo "adding our CA"
cat /ca.pem >> /etc/ssl/certs/ca-certificates.crt

echo "spinning waiting for shells"
/bin/sleep inf
