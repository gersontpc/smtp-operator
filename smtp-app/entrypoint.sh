#!/bin/sh
# configure postfix main.cf based on environment variables
set -e

# if DEBUG is set, enable shell tracing and Postfix verbose mode
if [ -n "$DEBUG" ]; then
    set -x
    # increase postfix debug level for SMTP
    postconf -e "debug_peer_level = 3"
    postconf -e "debug_peer_list = 127.0.0.1"
    # will pass -v flag when invoking postfix at the end
    DEBUG_FLAG="-v"
fi

# default variables
: ${RELAY_HOST:=smtp.gmail.com:587}
: ${RELAY_USER:?"RELAY_USER is required"}
: ${RELAY_PASSWORD:?"RELAY_PASSWORD is required"}

# write sasl password file
cat <<EOF > /etc/postfix/sasl_passwd
${RELAY_HOST} ${RELAY_USER}:${RELAY_PASSWORD}
EOF
# generate db map, some distributions might not create the .db file if postmap is missing
if command -v postmap >/dev/null 2>&1; then
    postmap /etc/postfix/sasl_passwd || true
fi
chmod 600 /etc/postfix/sasl_passwd
# only chmod database if it actually exists
if [ -f /etc/postfix/sasl_passwd.db ]; then
    chmod 600 /etc/postfix/sasl_passwd.db
fi

# configure main.cf minimal
postconf -e "relayhost = ${RELAY_HOST}"
postconf -e "smtp_sasl_auth_enable = yes"
postconf -e "smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd"
postconf -e "smtp_sasl_security_options = noanonymous"
postconf -e "smtp_use_tls = yes"
postconf -e "smtp_tls_security_level = encrypt"
postconf -e "smtp_tls_note_starttls_offer = yes"
postconf -e "myorigin = /etc/mailname"
[ -n "${MYDOMAIN}" ] && postconf -e "myhostname=${MYDOMAIN}"

# allow all networks (unsafe but fits relay use inside cluster)
postconf -e "mynetworks = 0.0.0.0/0"

# ensure postfix data directories exist
postfix check || true

# exec the command (append verbose flag if requested)
if [ -n "$DEBUG_FLAG" ]; then
    exec "$@" "$DEBUG_FLAG"
else
    exec "$@"
fi
