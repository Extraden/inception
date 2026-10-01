FROM debian:bookworm

RUN apt-get update \
	&& apt-get install -y nginx openssl \
	&& rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/nginx/ssl \
	&& openssl req \
	-x509 \
	-nodes \
	-newkey rsa:2048 \
	-days 365 \
	-keyout /etc/nginx/ssl/dsemenov.42.fr.key \
	-out /etc/nginx/ssl/dsemenov.42.fr.crt \
	-subj "/C=FR/ST=Rhone/L=Lyon/O=42/OU=42/CN=dsemenov.42.fr"

COPY conf/nginx.conf /etc/nginx/nginx.conf

EXPOSE 443

CMD ["nginx", "-g", "daemon off;"]
