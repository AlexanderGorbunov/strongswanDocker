#!/bin/bash

. ./variables.sh

name="$1"

if [ -z "$name" ]; then
  echo "Usage: $0 username" >&2
  echo "Example: $0 user01" >&2
  exit 1
fi

case "$name" in
  *[\\\"\']*)
    echo "VPN credentials must not contain any of these characters: \\ \" '" >&2
    exit 1
    ;;
esac

keyname="${name}_key.pem"
certname="${name}_cert.pem"
p12name="${name}_cert.p12"
CLIENT_CN="${name}@$DOMAIN"

echo "Generting private key for the user $name"
pki --gen \
    --outform pem > /etc/ipsec.d/private/"$keyname"
echo "Generting and signing certificate for the user $name"
pki --issue \
    --in /etc/ipsec.d/private/"$keyname" \
    --type priv \
    --cacert "$CA_CERT" --cakey "$CA_KEY" \
    --dn "C=$C, O=$O, CN=$CLIENT_CN" \
    --san="$CLIENT_CN" \
    --outform pem > /etc/ipsec.d/certs/"$certname"
echo "Exporting p12 for the user $name"
openssl pkcs12 -export \
    -inkey /etc/ipsec.d/private/"$keyname" \
    -in /etc/ipsec.d/certs/"$certname" \
    -name "$CLIENT_CN" \
    -certfile "$CA_CERT" \
    -caname "$CN" \
    -out /etc/ipsec.d/private/"$p12name" \
    -passout pass:112131 \
    -legacy

echo : RSA $keyname>> /etc/ipsec.secrets

ipsec rereadsecrets

echo "User added"
