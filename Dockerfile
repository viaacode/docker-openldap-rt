FROM debian:buster-slim
MAINTAINER Herwig Bogaert 

ENV RecoveryArea /recovery_area
ENV RecoverySocket "unix:/recovery_socket"
ARG RecoveryAreaGid=4
ARG LdapPort=8389
ENV LdapPort $LdapPort

# Install slapd and remove the preconfigured backend
RUN apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
  procps psmisc db-util ldap-utils slapd socat && \
  rm -rf /var/lib/apt/lists/* && \
  find /etc/ldap/slapd.d/ -type f \
  -exec grep -qi '^olcDbDirectory:.*/var/lib/ldap' {} \; -exec rm {} \; && \
  rm -f /var/lib/ldap/*

VOLUME /var/lib/ldap

COPY *.ldif /docker-entrypoint-init/

COPY configure_ldap_access.sh /usr/local/bin/
COPY recover.sh /usr/local/bin/
COPY load.sh /usr/local/bin/
COPY docker-entrypoint.sh /usr/local/bin/
COPY docker-entrypoint-init.sh /usr/local/bin/

# Arange access so that the containr can run non-privileged
#   Enable passwordless access via shared memory for openldap user
RUN /usr/local/bin/configure_ldap_access.sh
#   local openldap user can write to the recovery socket and access the recovery area
RUN usermod -G $RecoveryAreaGid openldap
#   local openldap user can drop in initialization files
RUN chown -R openldap:openldap /docker-entrypoint-init/

# Run as a non-privileged container
USER openldap

# Which implies using a non privilged port
EXPOSE $LdapPort


ENTRYPOINT ["docker-entrypoint.sh"]
