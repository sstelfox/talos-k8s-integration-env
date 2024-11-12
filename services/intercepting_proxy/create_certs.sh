#!/usr/bin/env sh

set -o errexit

echo -e "XX\n\n \n \n\n*\n\n" | openssl req -new -x509 -newkey \
  rsa:2048 -keyout certs/proxy.key -nodes -days 90 -out certs/proxy.crt &> /dev/null
