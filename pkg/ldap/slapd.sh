#!/bin/bash

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
#
# Copied from library/mysql entrypoint
file_env() {
        local var="$1"
        local fileVar="${var}_FILE"
        local def="${2:-}"
        if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
                echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
                exit 1
        fi
        local val="$def"
        if [ "${!var:-}" ]; then
                val="${!var}"
        elif [ "${!fileVar:-}" ]; then
                if [ -f "${!fileVar:-}" ]; then
                      val="$(< "${!fileVar}")"
                fi
        fi
        export "$var"="$val"
        unset "$fileVar"
}

# docker entrypoint script
# configures and starts LDAP

# # ensure certificates exist
# RETRY=0
# MAX_RETRIES=3
# until [ -f "$CERT_KEY" ] && [ -f "$CERT_FILE" ] && [ -f "$CA_FILE" ] || [ "$RETRY" -eq "$MAX_RETRIES" ]; do
#   RETRY=$((RETRY+1))
#   echo "Cannot find certificates. Retry ($RETRY/$MAX_RETRIES) ..."
#   sleep 1
# done
#
# # exit if no certificates were found after maximum retries
# if [ "$RETRY" -eq "$MAX_RETRIES" ]; then
#   echo "Cannot start ldap, the following certificates do not exist"
#   echo " CA_FILE:   $CA_FILE"
#   echo " CERT_KEY:  $CERT_KEY"
#   echo " CERT_FILE: $CERT_FILE"
#   exit 1
# fi

# replace variables in slapd.conf
SLAPD_CONF="/etc/openldap/slapd.conf"
file_env 'ROOT_USER' 'admin'
file_env 'SUFFIX' 'dc=example,dc=org'
# sed -i "s~%CA_FILE%~$CA_FILE~g" "$SLAPD_CONF"
# sed -i "s~%CERT_KEY%~$CERT_KEY~g" "$SLAPD_CONF"
# sed -i "s~%CERT_FILE%~$CERT_FILE~g" "$SLAPD_CONF"
sed -i "s~%ROOT_USER%~$ROOT_USER~g" "$SLAPD_CONF"
sed -i "s~%SUFFIX%~$SUFFIX~g" "$SLAPD_CONF"

# encrypt root password before replacing
file_env 'ROOT_PW' 'password'
ROOT_PW=$(slappasswd -s "$ROOT_PW")
sed -i "s~%ROOT_PW%~$ROOT_PW~g" "$SLAPD_CONF"

# replace variables in organisation configuration
ORG_CONF="/etc/openldap/organisation.ldif"
file_env 'ORGANISATION_NAME' 'Example.org (c)'
sed -i "s~%SUFFIX%~$SUFFIX~g" "$ORG_CONF"
sed -i "s~%ORGANISATION_NAME%~$ORGANISATION_NAME~g" "$ORG_CONF"

# add organisation and users to ldap (order is important)
slapadd -l "$ORG_CONF"

# add any scripts in ldif
for l in /ldif/*; do
  case "$l" in
    *.ldif)  echo "ENTRYPOINT: adding $l";
            slapadd -l $l
            ;;
    *)      echo "ENTRYPOINT: ignoring $l" ;;
  esac
done

# ensure /var/run/openldap exists
mkdir -p /var/run/openldap

# start ldap
slapd -h "ldap:///" -d 1
