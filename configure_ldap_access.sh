#!/bin/bash
coproc slapd { exec /usr/sbin/slapd -d 192 -u openldap -g openldap -h ldapi:/// 2>&1 ; }
exec 3<&${slapd[0]}

# Wait for ldap initialization
while read -r -u3 line; do
    echo "$line"
    [ $(expr "$line" : '.* slapd starting') -gt 0 ] && break
done

# read and dispaly slapd standard output
cat <&3 &

# Grant 'external' SASL access to the configuration database
# for the local 'openldap' user. This allows to container to run unpriviliged
ldapmodify -v -H ldapi:/// -Y external <<EOF
dn: olcDatabase={0}config,cn=config
changetype: modify
add: olcAccess
olcAccess: to * by dn.exact=gidNumber=$(id -g openldap)+uidNumber=$(id -u openldap),cn=peercred,cn=external,cn=auth manage by * break
EOF

kill $slapd_PID
wait $slapd_PID

