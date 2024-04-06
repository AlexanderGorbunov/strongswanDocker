#!/bin/bash

docker stop ikev2-vpn-server
docker rm ikev2-vpn-server
docker rmi strongswan-dockerme_vpn

rm -rf /data
mkdir -p ./data
touch ./data/ipsec.secrets
docker compose up -d
