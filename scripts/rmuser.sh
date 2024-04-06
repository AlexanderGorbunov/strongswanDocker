#!/bin/sh

VPN_USER="$1"

if [ -z "$VPN_USER" ]; then
  echo "Usage: $0 username" >&2
  echo "Example: $0 jordi" >&2
  exit 1
fi

#cp /etc/ipsec.secrets /usr/local/etc/ipsec.secrets.bak
#sed "/$VPN_USER :/d" /etc/ipsec.secrets.bak > /etc/ipsec.secrets # удаляем строку и с пользователем из файла /etc/ipsec.secrets

grep -q "$VPN_USER" /etc/ipsec.secrets && sed -i "/$VPN_USER/d" /etc/ipsec.secrets

ipsec rereadsecrets
