FROM debian:jessie
MAINTAINER Herwig Bogaert 

ENV RecoveryArea /recovery_area
ENV RecoverySocket "unix:/recovery_socket"
ARG RecoverySocketGid=4
ARG LdapPort=8389
ENV LdapPort $LdapPort

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y \
  db-util ldap-utils slapd socat \
  && rm -rf /var/lib/apt/lists/*

VOLUME /var/lib/ldap

COPY docker-entrypoint.sh /usr/local/bin/
COPY configure_ldap_access.sh /usr/local/bin/
COPY recover.sh /usr/local/bin/

COPY *.ldif /docker-entrypoint-init/

# Arange access so that the containr can run non-privileged
#   Enable passwordless access via shared memory for openldap user
RUN /usr/local/bin/configure_ldap_access.sh
#   local openldap user can write to the recovery socket and access the recovery area
RUN usermod -G $RecoverySocketGid openldap
#   local openldap user can drop in initialization files
RUN chown openldap:openldap /docker-entrypoint-init/

# Run as a non-privileged container
USER openldap

# Which implies using a non privilged port
EXPOSE $LdapPort

ENTRYPOINT ["docker-entrypoint.sh"]
