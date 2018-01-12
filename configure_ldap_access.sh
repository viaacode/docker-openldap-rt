#!/bin/bash
/usr/sbin/slapd -u openldap -g openldap -h ldapi:///

# Grant 'external' SASL access to the configuration database
# for the local 'openldap' user
ldapmodify -v -H ldapi:/// -Y external <<EOF
dn: olcDatabase={0}config,cn=config
changetype: modify
add: olcAccess
olcAccess: to * by dn.exact=gidNumber=$(id -g openldap)+uidNumber=$(id -u openldap),cn=peercred,cn=external,cn=auth manage by * break
EOF

pkill slapd 
while killall -s0 slapd; do sleep 1; done 2>/dev/null
