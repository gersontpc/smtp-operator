#!/bin/sh
# configura o main.cf do postfix a partir de variáveis de ambiente
set -e

# se DEBUG estiver setado, habilita trace dos comandos e modo verbose do Postfix
if [ -n "$DEBUG" ]; then
    set -x
    # aumenta o nível de debug do Postfix para SMTP
    postconf -e "debug_peer_level = 3"
    postconf -e "debug_peer_list = 127.0.0.1"
    # passará a flag -v ao invocar o postfix ao final
    DEBUG_FLAG="-v"
fi

# variáveis padrão
: ${RELAY_HOST:=smtp.gmail.com:587}
: ${RELAY_USER:?"RELAY_USER é obrigatório"}
: ${RELAY_PASSWORD:?"RELAY_PASSWORD é obrigatório"}
: ${MAILLOG_FILE:=/dev/stdout}

normalize_relay_host() {
    case "$1" in
        \[*\]) printf '%s\n' "$1" ;;
        *:*)
            relay_name=${1%:*}
            relay_port=${1##*:}
            printf '[%s]:%s\n' "$relay_name" "$relay_port"
            ;;
        *)
            printf '[%s]\n' "$1"
            ;;
    esac
}

RELAYHOST=$(normalize_relay_host "$RELAY_HOST")
DBTYPE=$(postconf -h default_database_type 2>/dev/null || printf 'hash\n')

MAILNAME=${MAILNAME:-${RELAY_USER#*@}}
printf '%s\n' "$MAILNAME" > /etc/mailname

# grava o arquivo de senha SASL
cat <<EOF > /etc/postfix/sasl_passwd
${RELAYHOST} ${RELAY_USER}:${RELAY_PASSWORD}
EOF
# gera o mapa de banco (hash, lmdb, etc.). Nem todas as distros criam .db automaticamente
if command -v postmap >/dev/null 2>&1; then
    postmap /etc/postfix/sasl_passwd
fi
chmod 600 /etc/postfix/sasl_passwd
# restringe permissões do arquivo de mapa gerado (hash/lmdb)
for map_file in /etc/postfix/sasl_passwd.db /etc/postfix/sasl_passwd.lmdb; do
    if [ -f "$map_file" ]; then
        chmod 600 "$map_file"
    fi
done

# configurações mínimas do main.cf
postconf -e "relayhost = ${RELAYHOST}"
postconf -e "smtp_sasl_auth_enable = yes"
postconf -e "smtp_sasl_password_maps = ${DBTYPE}:/etc/postfix/sasl_passwd"
postconf -e "smtp_sasl_security_options = noanonymous"
postconf -e "smtp_use_tls = yes"
postconf -e "smtp_tls_security_level = encrypt"
postconf -e "smtp_tls_note_starttls_offer = yes"
postconf -e "myorigin = /etc/mailname"
[ -n "${MAILLOG_FILE}" ] && postconf -e "maillog_file = ${MAILLOG_FILE}"
[ -n "${MYDOMAIN}" ] && postconf -e "myhostname=${MYDOMAIN}"

# remove cabeçalhos de confirmação de leitura/recebimento que alguns clientes adicionam
cat > /etc/postfix/header_checks <<'EOF'
/^Disposition-Notification-To:/    IGNORE
/^Return-Receipt-To:/              IGNORE
/^X-Confirm-Reading-To:/           IGNORE
EOF
postconf -e 'header_checks = regexp:/etc/postfix/header_checks'
postmap /etc/postfix/header_checks

# permite qualquer rede (inseguro, mas útil para relay dentro do cluster)
postconf -e "mynetworks = 0.0.0.0/0"

# garante que todos os diretórios de dados do postfix existem
postfix check || true

# garante que o banco de aliases exista (evita erro de arquivo não encontrado)
touch /etc/postfix/aliases
postalias /etc/postfix/aliases 2>/dev/null || true

# executa o comando final (adiciona flag verbose quando solicitado)
if [ -n "$DEBUG_FLAG" ]; then
    exec "$@" "$DEBUG_FLAG"
else
    exec "$@"
fi
