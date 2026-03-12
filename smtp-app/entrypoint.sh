#!/bin/sh
# configure postfix main.cf based on environment variables
set -e

# default variables
: ${RELAY_HOST:=smtp.gmail.com:587}
: ${RELAY_USER:?"RELAY_USER is required"}
: ${RELAY_PASSWORD:?"RELAY_PASSWORD is required"}

# write sasl password file
cat <<EOF > /etc/postfix/sasl_passwd
${RELAY_HOST} ${RELAY_USER}:${RELAY_PASSWORD}
EOF
postmap /etc/postfix/sasl_passwd
chmod 600 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db

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

# exec the command
exec "$@"
