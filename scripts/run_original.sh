#!/bin/bash

echo $(whoami)

LEFT_ID=$VPNHOST

echo "LEFT_ID = "
echo $LEFT_ID

INTERFACE=$(ip route show default | awk '/default/ {print $5}')


if [ -f "/SERVERS_FIRST_START" ]; then
	echo "This is server first startup"
	rm /etc/ipsec.conf
	rm /etc/ipsec.secrets
else
	echo "This is not server first startup"
fi

if [ ! -z "$DNS_SERVERS" ] ; then
	DNS=$DNS_SERVERS
else
	DNS="1.1.1.1,8.8.8.8"
fi

if [ -f "/SERVERS_FIRST_START" ]; then
	mkdir -p /cert/pki/{cacerts,certs,private}
	chmod 700 /cert/pki
	pki --gen --type rsa --size 4096 --outform pem > /cert/pki/private/ca-key.pem

	pki --self --ca --lifetime 3650 --in /cert/pki/private/ca-key.pem \
		--type rsa --dn "CN=scorpionVPN root CA" --outform pem > /cert/pki/cacerts/ca-cert.pem

	pki --gen --type rsa --size 4096 --outform pem > /cert/pki/private/server-key.pem

	pki --pub --in /cert/pki/private/server-key.pem --type rsa \
		| pki --issue --lifetime 1825 \
			--cacert /cert/pki/cacerts/ca-cert.pem \
			--cakey /cert/pki/private/ca-key.pem \
			--dn "CN=46.188.104.82" --san @46.188.104.82 --san 46.188.104.82 \
			--flag serverAuth --flag ikeIntermediate --outform pem \
		> /cert/pki/certs/server-cert.pem

	cp -r /cert/pki/* /etc/ipsec.d/
	cat /cert/pki/cacerts/ca-cert.pem
	cp -r /cert/pki/* /etc/ipsec.d/
fi


if [ ! -f "/etc/ipsec.conf" ]; then
cat > /etc/ipsec.conf <<EOF
config setup
	charondebug="ike 1, knl 1, cfg 1"
	uniqueids=no
conn ikev2-vpn
	auto=add
	compress=no
	type=tunnel
	keyexchange=ikev2
	fragmentation=yes
	forceencaps=yes
	dpdaction=clear
	dpddelay=300s
	rekey=no
	left=%any
	leftid=$LEFT_ID
	leftcert=server-cert.pem
	leftsendcert=always
	leftsubnet=0.0.0.0/0
	right=%any
	rightid=%any
	rightauth=eap-mschapv2
	rightsourceip=10.10.10.0/24
	rightdns=$DNS
	rightsendcert=never
	eap_identity=%identity
	ike=chacha20poly1305-sha512-curve25519-prfsha512,aes256gcm16-sha384-prfsha384-ecp384,aes256-sha1-modp1024,aes128-sha1-modp1024,3des-sha1-modp1024!
	esp=chacha20poly1305-sha512,aes256gcm16-ecp384,aes256-sha256,aes256-sha1,3des-sha1!
EOF
fi

if [ ! -f "/etc/ipsec.secrets" ]; then
cat > /etc/ipsec.secrets <<EOF
: RSA "server-key.pem"
TestUser : EAP "testpass"
EOF
fi

sysctl -p

#ufw enable
#ufw allow OpenSSH
#ufw allow 500,4500/udp

#sed -i "/^*filter.*/i \*nat\n-A POSTROUTING -s 10.10.10.0/24 -o $INTERFACE -m policy --pol ipsec --dir out -j ACCEPT\n-A POSTROUTING -s 10.10.10.0/24 -o $INTERFACE -j MASQUERADE\nCOMMIT\n\n\*mangle\n-A FORWARD --match policy --pol ipsec --dir in -s 10.10.10.0/24 -o $INTERFACE -p tcp -m tcp --tcp-flags SYN\,RST SYN -m tcpmss --mss 1361:1536 -j TCPMSS --set-mss 1360\nCOMMIT\n" /etc/ufw/before.rules
#sed -i "/^\# allow all on loopback*/i -A ufw-before-forward --match policy --pol ipsec --dir in --proto esp -s 10.10.10.0/24 -j ACCEPT\n-A ufw-before-forward --match policy --pol ipsec --dir out --proto esp -d 10.10.10.0/24 -j ACCEPT\n" /etc/ufw/before.rules

#echo "net/ipv4/ip_forward=1" >> /etc/ufw/sysctl.conf
#echo "net/ipv4/conf/all/accept_redirects=0" >> /etc/ufw/sysctl.conf
#echo "net/ipv4/conf/all/send_redirects=0" >> /etc/ufw/sysctl.conf
#echo "net/ipv4/ip_no_pmtu_disc=1" >> /etc/ufw/sysctl.conf

#ufw disable
#ufw enable
