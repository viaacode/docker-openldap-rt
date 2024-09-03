#!/bin/bash
# docker-entrypoint-init.sh
# Process the ldif files in /docker-entrypoint-init

# Start slapd without exposing it during configuration
# (listen only on internal unix domain socket)
coproc tailcop { exec /usr/sbin/slapd -d1 -h ldapi:/// 2>&1; }

exec 3<&${tailcop[0]}

while read -ru ${tailcop[0]} line; do
    echo $line
    [ $(expr "$line" : '.* slapd starting$') -gt 0 ] && break
done

echo "$(date '+%m/%d %H:%M:%S') ---- Configuring ldap ----"
cat <&3 &

# Process the ldif files
for f in $(ls /docker-entrypoint-init/*ldif 2>/dev/null); do
    grep -qi ^changetype: $f
    [ $? -eq 0 ] && Command=ldapmodify || Command=ldapadd
    echo "$Command -v -H ldapi:/// -Y external -f $f"
    $Command -v -H ldapi:/// -Y external -f $f
    [ $? -eq 0 ] && mv $f $f.done
done

echo "$(date '+%m/%d %H:%M:%S') ---- Shutting down slapd ----"
[ -n "$tailcop_PID" ] && kill $tailcop_PID && wait $tailcop_PID
