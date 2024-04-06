#!/bin/bash
docker stop ikev2-vpn-server
docker stop freeradius-server
docker rm ikev2-vpn-server
docker rm freeradius-server
docker rmi strongswan-dockerme-vpn:latest
sudo rm -rf ./data