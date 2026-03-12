# Basic POSIX container running postfix as SMTP relay to Gmail

FROM debian:stable-slim

# install postfix and sasl
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y postfix libsasl2-modules && \
    rm -rf /var/lib/apt/lists/*

# copy entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# expose SMTP port
EXPOSE 25

# run entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/sbin/postfix","start-fg"]
