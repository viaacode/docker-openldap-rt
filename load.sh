LdapData='/var/lib/ldap'
set -x

while getopts "d:l:t:" opt; do
    case $opt in
        d) DUMP1=$OPTARG
            ;;
        l) DUMP2=$OPTARG
            ;;
        t) Time=$OPTARG
            ;;
    esac
done

Time=${Time:=null}

if [ -n "$DUMP1" ] ; then
    
    # If data has already been recovered in a previous run, just start the container
    if [ -d $LdapData/data ]; then
        exec docker-entrypoint.sh
    fi
    
    DUMPFILE="$RecoveryArea/$(basename $DUMP1)"
    
    # Recover the dump file
    echo "$(date '+%m/%d %H:%M:%S'): Recovering dump file: $DUMPFILE"
    [ -r $DUMPFILE ] && rm $DUMPFILE
    cat <<EOF | socat -,ignoreeof $RecoverySocket
    { \
        "client": "$HOSTNAME", \
        "path": "$DUMP1", \
        "uid": "$(id -u openldap)", \
        "Time": "$Time" \
    }
EOF
    [ -r $DUMPFILE ] || exit 5
fi

# Temporary support for second dump
if [ -n "$DUMP2" ] ; then
    
    # If data has already been recovered in a previous run, just start the container
    if [ -d $LdapData/data ]; then
        exec docker-entrypoint.sh
    fi
    
    DUMPFILE="$RecoveryArea/$(basename $DUMP2)"
    
    # Recover the dump file
    echo "$(date '+%m/%d %H:%M:%S'): Recovering dump file: $DUMPFILE"
    [ -r $DUMPFILE ] && rm $DUMPFILE
    cat <<EOF | socat -,ignoreeof $RecoverySocket
    { \
        "client": "$HOSTNAME", \
        "path": "$DUMP2", \
        "uid": "$(id -u openldap)", \
        "Time": "$Time" \
    }
EOF
    [ -r $DUMPFILE ] || exit 5
fi

# Create LDAP data and log directories
mkdir -p $LdapData/data
mkdir -p $LdapData/log

# Create the bdb backends
cd "$RecoveryArea"
RC=0
for DumpFile in $(ls *.ldif*); do

    suffix=$(sed 's/.ldif.*$//' <<<$DumpFile)

    mkdir $LdapData/data/$suffix
    mkdir $LdapData/log/$suffix

    cat >>"/docker-entrypoint-init/99-bdb-$suffix.ldif" <<EOF
dn: olcDatabase=bdb,cn=config
objectClass: olcDatabaseConfig
objectClass: olcBdbConfig
olcDatabase: bdb
olcDbDirectory: $LdapData/data/$suffix
olcSuffix: $suffix
olcRootDN: cn=recoverytest,$suffix
olcDbConfig: {0}set_lg_dir $LdapData/log/$suffix
olcRootPW: ${RecoverySecret}
olcSizeLimit: 500000
EOF
    /usr/local/bin/docker-entrypoint-init.sh
    # Overwrite the DB_CONFIG environment file
    # because it needs to be in line with the ldap backend configuration
    echo "set_lg_dir $LdapData/log/$suffix" >$LdapData/data/$suffix/DB_CONFIG

    zcat $DumpFile | /usr/sbin/slapadd -F /etc/ldap/slapd.d -b $suffix -w 
    ExitCode=$?
    echo "$(date '+%m/%d %H:%M:%S'): Load ldif dump $suffix. Exitcode: $ExitCode"
    RC=$(( $RC + $ExitCode ))

done
echo "$(date '+%m/%d %H:%M:%S'): Database recovery ended with exitcode $RC"
#exit $RC
exec docker-entrypoint.sh
