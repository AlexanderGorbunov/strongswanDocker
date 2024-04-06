#!/bin/bash

. ./variables.sh
if [ -f "/SERVERS_FIRST_START" ]; then
	echo "This is server first startup"
	echo $(whoami)
	
	LEFT_ID=$VPNHOST
	echo "LEFT_ID = $LEFT_ID"

	INTERFACE=$(ip route show default | awk '/default/ {print $5}')
	rm /etc/ipsec.conf
	rm /etc/ipsec.secrets
	#rm /etc/strongswan.conf
	
	if [ ! -z "$DNS_SERVERS" ] ; then
        DNS=$DNS_SERVERS
	else
        DNS="8.8.8.8,8.8.4.4"
	fi

	IFS=',' read -ra clients_array <<< "$clients_list"
	clients_list=$(echo "$clients_list" | tr -d ' ')
	for client in "${clients_array[@]}"; do
    	echo "Client: $client"
	done
	
	mkdir -p /cert/pki/{cacerts,certs,private}
	chmod 700 /cert/pki
	pki --gen --type rsa --size 4096 --outform pem > /cert/pki/private/ca_key.pem

	pki --self --ca --lifetime 3650 --in /cert/pki/private/ca_key.pem \
			--type rsa --dn "$CA_DN" --outform pem > /cert/pki/cacerts/ca_cert.pem

	pki --gen --type rsa --size 4096 --outform pem > /cert/pki/private/server_key.pem

	pki --pub --in /cert/pki/private/server_key.pem --type rsa \
			| pki --issue --lifetime 1825 \
					--cacert /cert/pki/cacerts/ca_cert.pem \
					--cakey /cert/pki/private/ca_key.pem \
					--dn "$SERVER_DN" --san "$SERVER_SAN" --san "$REMOTE_ID_FULL" \
					--flag serverAuth --flag ikeIntermediate --outform pem \
			> /cert/pki/certs/server_cert.pem

	cp -r /cert/pki/* /etc/ipsec.d/
	cat /cert/pki/cacerts/ca_cert.pem
	
	
	cat > /etc/ipsec.conf <<EOF
config setup
	charondebug="ike 1, knl 1, cfg 1"
	#charondebug="ike 2, cfg 2, esp 2, 500"
	uniqueids=no
		
conn %default
	auto=add
    compress=no
    type=tunnel
	keyexchange=ikev2
    fragmentation=yes
    forceencaps=yes
	dpddelay=120s
	rekey=no
	ikelifetime=60m
	keylife=20m
	rekeymargin=3m
	keyingtries=1
	ike=chacha20poly1305-sha512-curve25519-prfsha512,aes256gcm16-sha384-prfsha384-ecp384,aes256gcm16-sha256-prfsha256-ecp256,aes256-sha1-modp1024,aes128-sha1-modp1024,3des-sha1-modp1024!
    esp=chacha20poly1305-sha512,aes256gcm16-ecp384,aes256-sha256,aes256-sha1,3des-sha1!
#	 ike=chacha20poly1305-prfsha256-newhope128,chacha20poly1305-prfsha256-ecp256,aes128gcm16-prfsha256-ecp256,aes256-sha256-modp2048,aes256-sha256-modp1024!
#    esp=chacha20poly1305-newhope128,chacha20poly1305-ecp256,aes128gcm16-ecp256,aes256-sha256-modp2048,aes256-sha256,aes256-sha1!
	dpdaction=clear
	rightdns=$DNS

conn roadwarrior-full
	left=%any
	#This is "Remote ID" that we'll use on the client to select connection. See notes below
	leftid=@$REMOTE_ID_FULL
	leftauth=pubkey
	leftcert=server_cert.pem
	leftsendcert=always
	leftsubnet=0.0.0.0/0
	right=%any
	rightid=%any
	rightauth=pubkey
	rightsourceip=10.10.10.0/24

conn roadwarrior-eap-full
	also=roadwarrior-full
	rightauth=eap-mschapv2
	eap_identity=%any

#conn ikev2-vpn
#	compress=no
#	type=tunnel
#	fragmentation=yes
#	forceencaps=yes
#	left=%any
#	leftid=$LEFT_ID
#	leftcert=server_cert.pem
#	leftsendcert=always
#	leftsubnet=0.0.0.0/0
#	right=%any
#	rightid=%any
#	rightauth=eap-mschapv2
#	rightsourceip=10.10.10.0/24
#	rightdns=$DNS
#	rightsendcert=never
#	eap_identity=%identity
#	ike=chacha20poly1305-sha512-curve25519-prfsha512,aes256gcm16-sha384-prfsha384-ecp384,aes256-sha1-modp1024,aes128-sha1-modp1024,3des-sha1-modp1024,aes256-sha256-modp2048!
#	esp=chacha20poly1305-sha512,aes256gcm16-ecp384,aes256-sha256,aes256-sha1,3des-sha1!
EOF

	cat > /etc/ipsec.secrets <<EOF
: RSA "server_key.pem"

# EAP secrets and Users' private keys
# TestUser : EAP "testpass"
#: RSA test_scorpion_key.pem
scorpEAP : EAP "eQt8s4WV3kUN"
EOF

#cat > /etc/strongswan.conf <<EOF
#charon {
#  send_vendor_id = yes
#  plugins {
#    eap-dynamic {
#      preferred = mschapv2, tls, md5
#    }
#    dhcp {
#      identity_lease = no
#    }
#  }
#}
#EOF

	for client in "${clients_array[@]}"; do
		bash generateuser.sh $client
	done
	
	sysctl -p

	ufw enable
	ufw allow 500,4500/udp

	sed -i "/^*filter.*/i \*nat\n-A POSTROUTING -s 10.10.10.0/24 -o $INTERFACE -m policy --pol ipsec --dir out -j ACCEPT\n-A POSTROUTING -s 10.10.10.0/24 -o $INTERFACE -j MASQUERADE\nCOMMIT\n\n\*mangle\n-A FORWARD --match policy --pol ipsec --dir in -s 10.10.10.0/24 -o $INTERFACE -p tcp -m tcp --tcp-flags SYN\,RST SYN -m tcpmss --mss 1361:1536 -j TCPMSS --set-mss 1360\nCOMMIT\n" /etc/ufw/before.rules
	sed -i "/^\# allow all on loopback*/i -A ufw-before-forward --match policy --pol ipsec --dir in --proto esp -s 10.10.10.0/24 -j ACCEPT\n-A ufw-before-forward --match policy --pol ipsec --dir out --proto esp -d 10.10.10.0/24 -j ACCEPT\n" /etc/ufw/before.rules

	echo "net/ipv4/ip_forward=1" >> /etc/ufw/sysctl.conf
	echo "net/ipv4/conf/all/accept_redirects=0" >> /etc/ufw/sysctl.conf
	echo "net/ipv4/conf/all/send_redirects=0" >> /etc/ufw/sysctl.conf
	echo "net/ipv4/ip_no_pmtu_disc=1" >> /etc/ufw/sysctl.conf

	ufw disable
	ufw enable
	
	rm /SERVERS_FIRST_START
	
else
	echo "This is not server first startup"
fi

ipsec start --nofork
