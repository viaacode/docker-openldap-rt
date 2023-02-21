#!/bin/bash
# docker-entrypoint-init.sh
# Process the ldif files in /docker-entrypoint-init

# Start slapd without exposing it
# (listen only on internal unix domain socket)
/usr/sbin/slapd -h ldapi:///

# Process the ldif files
for f in $(ls /docker-entrypoint-init/*ldif 2>/dev/null); do
    grep -qi ^changetype: $f
    [ $? -eq 0 ] && Command=ldapmodify || Command=ldapadd
    echo "$Command -v -H ldapi:/// -Y external -f $f"
    $Command -v -H ldapi:/// -Y external -f $f
    [ $? -eq 0 ] && mv $f $f.done
done

# Stop slapd
pkill slapd
while killall -s0 slapd 2>/dev/null; do sleep 1; done
