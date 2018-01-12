#!/bin/bash
if [ -z "$1" ] || [ "${1:0:1}" == '-' ]; then
    set -- slapd -d1 -h ldap://:$LdapPort/ "$@"
fi

if [ $(basename $1) == 'slapd' ]; then 
    /usr/sbin/slapd -h ldapi:///
    for f in $(ls /docker-entrypoint-init/*ldif 2>/dev/null); do
        grep -qi ^changetype: $f
        [ $? -eq 0 ] && Command=ldapmodify || Command=ldapadd
        $Command -v -H ldapi:/// -Y external -f $f
        [ $? -eq 0 ] && mv $f $f.done
    done
    pkill slapd
    while killall -s0 slapd 2>/dev/null; do sleep 1; done
fi


exec $@ 
