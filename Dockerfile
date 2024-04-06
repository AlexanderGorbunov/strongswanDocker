FROM ubuntu:latest

# Install strongSwan
RUN apt update \
	&& apt install -y ufw nano strongswan strongswan-pki libcharon-extra-plugins libcharon-extauth-plugins libstrongswan-extra-plugins libtss2-tcti-tabrmd0 \
	&& touch /SERVERS_FIRST_START
	
COPY ./scripts/variables.sh /variables.sh
COPY ./scripts/run.sh /run.sh
COPY ./scripts/adduser.sh /adduser.sh
COPY ./scripts/generateuser.sh /generateuser.sh
COPY ./scripts/rmuser.sh /rmuser.sh

RUN chmod 755 /run.sh /adduser.sh /rmuser.sh /generateuser.sh

EXPOSE 500:500/udp 4500:4500/udp

CMD ["/run.sh"]
