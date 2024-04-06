#!/bin/bash
# Country code and Org name
C=$Country
O=$Organization

# Root Certificate Configuration
CA_DN="C=$C, O=$O, CN=$CommonName" 
CA_KEY="/etc/ipsec.d/private/ca_key.pem"
CA_CERT="/etc/ipsec.d/cacerts/ca_cert.pem"

# VPN Server Configuration
DOMAIN=$Domain
SERVER_SAN="vpn.$DOMAIN"
REMOTE_ID_FULL="$REMOTE_ID_FULL.$SERVER_SAN"

SERVER_DN="C=$C, O=$O, CN=$SERVER_SAN"
SERVER_KEY="/etc/ipsec.d/private/server_key.pem"
SERVER_CERT="/etc/ipsec.d/certs/server_cert.pem"
