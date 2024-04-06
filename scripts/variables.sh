#!/bin/bash
# Country code and Org name
C="RU"
O="Racknerd point"

# Root Certificate Configuration
CA_DN="C=$C, O=$O, CN=Scorpion's remote point Root CA" 
CA_KEY="/etc/ipsec.d/private/ca_key.pem"
CA_CERT="/etc/ipsec.d/cacerts/ca_cert.pem"

# VPN Server Configuration
DOMAIN="alexander.ru"
SERVER_SAN="vpn.$DOMAIN"
REMOTE_ID_FULL="full-tunnel.$SERVER_SAN"

SERVER_DN="C=$C, O=$O, CN=$SERVER_SAN"
SERVER_KEY="/etc/ipsec.d/private/server_key.pem"
SERVER_CERT="/etc/ipsec.d/certs/server_cert.pem"
