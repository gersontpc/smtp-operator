# Minimal Alpine container running postfix as SMTP relay to Gmail

FROM alpine:3.18

# install postfix, cyrus-sasl and other dependencies
RUN apk add --no-cache postfix cyrus-sasl bash \
    && postconf -e "inet_interfaces = all" \
    && postconf -e "mydestination = localhost"

# copy entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# expose SMTP port
EXPOSE 25

# run entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/sbin/postfix","start-fg"]
