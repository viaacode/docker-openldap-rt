LdapData='/var/lib/ldap'
while getopts ":d:l:t:" opt; do
    case $opt in
        d) SrcDataDir=$OPTARG
            ;;
        l) SrcLogDir=$OPTARG
            ;;
        t) Time=$OPTARG
            ;;
    esac
done

# If data has already been recovered in a previous run, just start the container
if [ ! -d $LdapData/data ]; then

  [ -z $SrcDataDir ] || [ -z $SrcLogDir ] && exit 3
  Time=${Time:=null}
  
  DataDir=$(basename $SrcDataDir)
  LogDir=$(basename $SrcLogDir)
  
  # Recover the LDAP databases and transaction logs
  for dir in $SrcDataDir $SrcLogDir; do
  
      rm -fr $RecoveryArea/$(basename $dir)/*
      echo "$(date '+%m/%d %H:%M:%S'): Restoring $dir"
      cat <<EOF | socat -,ignoreeof $RecoverySocket
          { \
              "client": "$HOSTNAME", \
              "path": "$dir", \
              "uid": "$(id -u openldap)", \
              "Time": "$Time" \
          }
EOF
  done
  [ -d $RecoveryArea/$DataDir ] && [ -d $RecoveryArea/$LogDir ] || exit 5
  
  # The datadir contains a directory for each backend with the suffix as name
  # The backend lis is the list all the directories with an '=' caharcter in the
  # name, which is what every suffix has
  Backends=$(cd $RecoveryArea/$DataDir && echo *=*)
  
  # Create LDAP data and log directories
  mkdir -p $LdapData/data
  mkdir -p $LdapData/log
  
  # Create the bdb backends
  RC=0
  for suffix in $Backends; do 
  
      mkdir $LdapData/data/$suffix
      mkdir $LdapData/log/$suffix
  
      # This ldif file will be executed by docker-entrypoint.sh
      cat >/docker-entrypoint-init/bdb$suffix.ldif <<EOF
dn: olcDatabase=bdb,cn=config
objectClass: olcDatabaseConfig
objectClass: olcBdbConfig
olcDatabase: bdb
olcDbDirectory: $LdapData/data/$suffix
olcSuffix: $suffix
olcRootDN: cn=recoverytest,$suffix
olcDbConfig: {0}set_lg_dir $LdapData/log/$suffix
olcRootPW: ${RecoverySecret}
olcSizeLimit: 5000
EOF
      # Replace the contents of the created backends with the recovered data
      cd $LdapData/data/
      # Overwrite the DB_CONFIG environment file
      # because it needs to be in line with the ldap backend configuration
      echo "set_lg_dir $LdapData/log/$suffix" >$RecoveryArea/$DataDir/$suffix/DB_CONFIG
      rm -fr $suffix
      ln -s $RecoveryArea/$DataDir/$suffix
  
      cd $LdapData/log
      rm -fr $suffix
      ln -s $RecoveryArea/$LogDir/$suffix
  
      cd $LdapData/data/$suffix
      # At least the following files should have been recovered
      [ -e "id2entry.bdb" ] && [ -e "dn2id.bdb" ]
      ExitCode=$?
      echo "$(date '+%m/%d %H:%M:%S'): Base file check of $suffix. Exitcode: $ExitCode"
      RC=$(( $RC + $ExitCode ))
  
      echo "$(date '+%m/%d %H:%M:%S'): Recovering database $suffix"
      if [ "$Time" == 'null' ] ; then
          /usr/bin/db_recover -c -v -h ./
      else
          /usr/bin/db_recover -c -v -h -t $Time ./ 
      fi
      ExitCode=$?
      echo "$(date '+%m/%d %H:%M:%S'): Recovery of $suffix. Exitcode: $ExitCode"
      RC=$(( $RC + $ExitCode ))
  
      /usr/bin/db_verify *bdb
      ExitCode=$?
      RC=$(( $RC + $ExitCode ))
  done
  echo "$(date '+%m/%d %H:%M:%S'): Database recovery ended with exitcode $RC"
fi
exec docker-entrypoint.sh
