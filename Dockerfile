FROM  armhf/alpine:3.5
MAINTAINER Pat Downey <pat.downey@gmail.com> (@pat_downey)

ENV CADDY_FEATURES=DNS,awslambda,cors,expires,filemanager,filter,git,hugo,ipfilter,jsonp,jwt,locale,mailout,minify,multipass,prometheus,ratelimit,realip,search,upload,cloudflare,digitalocean,dnsimple,dyn,gandi,googlecloud,linode,namecheap,ovh,rfc2136,route53,vultr

#https://caddyserver.com/download/build?os=linux&arch=arm&features=DNS,awslambda,cors,expires,filemanager,filter,git,hugo,ipfilter,jsonp,jwt,locale,mailout,minify,multipass,prometheus,ratelimit,realip,search,upload,cloudflare,digitalocean,dnsimple,dyn,gandi,googlecloud,linode,namecheap,ovh,rfc2136,route53,vultr&arm=6

#    curl --location --silent https://caddyserver.com/download/build?os=linux&arch=arm&features=&arm=6 | tar zxfv - /bin/caddy github.com/tianon/gosu/releases/download/1.10/gosu-armhf > /bin/gosu && \

#curl --location --silent | tar zxfv - caddy

# Create a caddy user and group first so the IDs get set the same way,
# even as the rest of this may change over time.
RUN addgroup caddy && \
    adduser -S -G caddy caddy 

#curl --location --silent https://caddyserver.com/download/build?os=linux&arch=arm&features=&arm=6 | tar zxfv - /bin/caddy g

# Set up certificates, our base tools, and Vault.
RUN apk add --no-cache curl ca-certificates gnupg openssl libcap dumb-init
RUN    curl --location --silent https://github.com/tianon/gosu/releases/download/1.10/gosu-armhf > /bin/gosu && \
    chmod +x /bin/gosu 
RUN curl --location --silent "https://caddyserver.com/download/build?os=linux&arch=arm&features=${CADDY_FEATURES}&arm=6" | tar zxfv - -C /bin caddy 
RUN  apk del gnupg openssl 

# /caddy/logs is made available to use as a location to store audit logs, if
# desired; /caddy/file is made available to use as a location with the file
# storage backend, if desired; the server will be started with /vault/config as
# the configuration directory so you can add additional config files in that
# location.
RUN mkdir -p /caddy/logs && \
    mkdir -p /caddy/config && \
    chown -R caddy:caddy /caddy

# Expose the logs directory as a volume since there's potentially long-running
# state in there
VOLUME /caddy/logs

# 8200/tcp is the primary interface that applications use to interact with
# Vault.
EXPOSE 443

# The entry point script uses dumb-init as the top-level process to reap any
# zombie processes created by Vault sub-processes.
#
# For production derivatives of this container, you shoud add the IPC_LOCK
# capability so that Vault can mlock memory.
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["docker-entrypoint.sh"]

# By default you'll get a single-node development server that stores everything
# in RAM and bootstraps itself. Don't use this configuration for production.
CMD ["caddy"]
