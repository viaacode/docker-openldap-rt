#!/bin/bash
set -x
if [ -z "$1" ] || [ "${1:0:1}" == '-' ]; then
    set -- slapd -d1 -h "ldapi:/// ldap://:$LdapPort/" "$@"
fi

if [ $(basename $1) == 'slapd' ]; then 
    # Initialise the ldap server
    /usr/local/bin/docker-entrypoint-init.sh
fi

exec "$@" 
