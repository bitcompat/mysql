# syntax=docker/dockerfile:1.4

ARG SERVER_VERSION

FROM docker.io/bitnami/minideb:bullseye as builder

ARG TARGETPLATFORM

COPY prebuildfs /
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN install_packages curl ca-certificates tar build-essential cmake make g++ libssl-dev libldap2-dev libsasl2-dev  \
    libkrb5-dev pkg-config libsasl2-modules-gssapi-mit libncurses5-dev libudev-dev bison libaio-dev
RUN mkdir -p /bitnami/blacksmith-sandox/

ARG SERVER_VERSION
ADD --link https://github.com/mysql/mysql-server/archive/refs/tags/mysql-${SERVER_VERSION}.tar.gz /bitnami/blacksmith-sandox/mysql-${SERVER_VERSION}.tar.gz
RUN <<EOT bash
    set -ex
    cd /bitnami/blacksmith-sandox
    tar xvf mysql-${SERVER_VERSION}.tar.gz

    mv mysql-server-mysql-${SERVER_VERSION} mysql-${SERVER_VERSION}
    cd mysql-${SERVER_VERSION}

    cmake -DBUILD_CONFIG=mysql_release -DCMAKE_INSTALL_PREFIX=/opt/bitnami/mysql -DCMAKE_BUILD_TYPE=RelWithDebInfo \
     -DHANDLE_FATAL_SIGNALS=ON -DMYSQLX_GENERATE_DIR=/bitnami/blacksmith-sandox/mysql-${SERVER_VERSION}/plugin/x/generated \
     -DFORCE_INSOURCE_BUILD=1 -DMYSQL_DATADIR=/opt/bitnami/mysql/data -DMYSQL_ICU_DATADIR=/opt/bitnami/mysql/lib/private \
     -DMYSQL_KEYRINGDIR=/opt/bitnami/mysql/keyring \
     -DWITH_ARCHIVE_STORAGE_ENGINE=ON -DWITH_AUTHENTICATION_CLIENT_PLUGINS=ON -DWITH_AUTHENTICATION_FIDO=OFF \
     -DWITH_AUTHENTICATION_KERBEROS=OFF -DWITH_AUTHENTICATION_LDAP=1 -DWITH_BLACKHOLE_STORAGE_ENGINE=ON \
     -DWITH_FEDERATED_STORAGE_ENGINE=ON -DWITH_MYSQLX=ON -DWITH_ROUTER=ON -DDOWNLOAD_BOOST=1 -DWITH_BOOST=/tmp/boost \
     -DWITH_UNIT_TESTS=OFF -DINSTALL_STATIC_LIBRARIES=OFF
    make -j$(nproc)
    make install
EOT

ARG DIRS_TO_TRIM="/opt/bitnami/mysql/man"

RUN <<EOT bash
    for DIR in $DIRS_TO_TRIM; do
      find \$DIR/ -delete -print
    done
EOT

RUN find /opt/bitnami/ -name "*.so*" -type f | xargs strip --strip-all
RUN find /opt/bitnami/ -executable -type f | xargs strip --strip-all || true

RUN rm -rf /opt/bitnami/mysql/bin/mysql_client_test
RUN rm -rf /opt/bitnami/mysql/bin/mysql_keyring_encryption_test
RUN rm -rf /opt/bitnami/mysql/bin/mysqltest*
RUN rm -rf /opt/bitnami/mysql/bin/mysqlxtest
RUN rm -rf /opt/bitnami/mysql/bin/mysql_client_test_embedded
RUN rm -rf /opt/bitnami/mysql/bin/mysql_embedded
RUN rm -rf /opt/bitnami/mysql/lib/libmysqlclient.a
RUN rm -rf /opt/bitnami/mysql/lib/libmysqld.a
RUN rm -rf /opt/bitnami/mysql/lib/libmysqlservices.a
RUN rm -rf /opt/bitnami/mysql/mysql-test

RUN mkdir -p /opt/bitnami/mysql/licenses
RUN cp /bitnami/blacksmith-sandox/mysql-${SERVER_VERSION}/LICENSE /opt/bitnami/mysql/licenses/mysql-${SERVER_VERSION}.txt
RUN echo "mysql-${SERVER_VERSION},GPL2,https://github.com/mysql/mysql-server/archive/refs/tags/mysql-${SERVER_VERSION}.tar.gz" > /opt/bitnami/mysql/licenses/gpl-source-links.txt

FROM docker.io/bitnami/minideb:bullseye as stage-0

COPY --link rootfs/ /
COPY --link --from=ghcr.io/bitcompat/gosu:1.14.0-bullseye-r1 /opt/bitnami/ /opt/bitnami/
COPY --link --from=ghcr.io/bitcompat/ini-file:1.4.3-bullseye-r1 /opt/bitnami/ /opt/bitnami/
COPY --link --from=builder /opt/bitnami/ /opt/bitnami/

RUN /opt/bitnami/scripts/mysql/postunpack.sh

FROM docker.io/bitnami/minideb:bullseye as stage-1

ARG SERVER_VERSION
ARG TARGETARCH
ENV HOME="/" \
    OS_ARCH="${TARGETARCH}" \
    OS_FLAVOUR="debian-11" \
    OS_NAME="linux" \
    APP_VERSION="8.0.30" \
    BITNAMI_APP_NAME="mysql" \
    PATH="/opt/bitnami/common/bin:/opt/bitnami/mysql/bin:/opt/bitnami/mysql/sbin:$PATH"

LABEL org.opencontainers.image.ref.name="${SERVER_VERSION}-debian-11-r1" \
      org.opencontainers.image.title="mysql" \
      org.opencontainers.image.version="${SERVER_VERSION}"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install required system packages and dependencies
COPY --from=stage-0 /opt/bitnami/ /opt/bitnami/
RUN <<EOT bash
    set -e
    install_packages acl ca-certificates curl gzip procps psmisc tar libaio1
    mkdir -p /docker-entrypoint-initdb.d /bitnami/mysql/data
    echo "" > /.mysqlsh
    chown 1001 /.mysqlsh
EOT

EXPOSE 3306

USER 1001
ENTRYPOINT [ "/opt/bitnami/scripts/mysql/entrypoint.sh" ]
CMD [ "/opt/bitnami/scripts/mysql/run.sh" ]
