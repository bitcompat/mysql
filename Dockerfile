# syntax=docker/dockerfile:1.4

ARG BUILD_VERSION
ARG DOCKER_ARCH=$TARGETARCH

FROM --platform=$BUILDARCH docker.io/bitnami/minideb:bullseye AS base-amd64

ENV DEBIAN_ARCH=amd64
ENV BUILD_ARCH=x86_64
ENV GCC_ARCH=x86-64
ENV \
    CC=x86_64-linux-gnu-gcc \
    CXX=x86_64-linux-gnu-g++

FROM --platform=$BUILDARCH docker.io/bitnami/minideb:bullseye AS base-arm64

ENV DEBIAN_ARCH=arm64
ENV BUILD_ARCH=aarch64
ENV GCC_ARCH=aarch64
ENV \
    CC=aarch64-linux-gnu-gcc \
    CXX=aarch64-linux-gnu-g++

FROM --platform=$BUILDARCH base-$TARGETARCH AS builder

COPY prebuildfs /
ENV BUILD_TARGET=${BUILD_ARCH}-unknown-linux-gnu

#RUN apt-get update \
#    && apt-get -y install llvm cmake git curl clang libcurl4-openssl-dev:${DEBIAN_ARCH} zip \
#    binutils-${GCC_ARCH}-linux-gnu libc6-${DEBIAN_ARCH}-cross \
#    libc6-dev-${DEBIAN_ARCH}-cross crossbuild-essential-${DEBIAN_ARCH} gcc-${GCC_ARCH}-linux-gnu \
#    g++-${GCC_ARCH}-linux-gnu libgcc-10-dev-${DEBIAN_ARCH}-cross

RUN dpkg --add-architecture ${DEBIAN_ARCH} \
    && install_packages curl ca-certificates tar crossbuild-essential-${DEBIAN_ARCH} cmake make \
    g++-${GCC_ARCH}-linux-gnu gcc-${GCC_ARCH}-linux-gnu binutils-${GCC_ARCH}-linux-gnu libc6-${DEBIAN_ARCH}-cross \
    libgcc-10-dev-${DEBIAN_ARCH}-cross libstdc++6-${DEBIAN_ARCH}-cross libstdc++6:${DEBIAN_ARCH} cpp \
    libssl-dev:${DEBIAN_ARCH} libldap2-dev:${DEBIAN_ARCH} libsasl2-dev:${DEBIAN_ARCH} libkrb5-dev:${DEBIAN_ARCH} pkg-config \
    libsasl2-modules-gssapi-mit:${DEBIAN_ARCH} libncurses5-dev:${DEBIAN_ARCH} libudev-dev:${DEBIAN_ARCH} bison libaio-dev:${DEBIAN_ARCH}
RUN mkdir -p /bitnami/blacksmith-sandox/

ARG BUILD_VERSION
ADD --link https://github.com/mysql/mysql-server/archive/refs/tags/mysql-${BUILD_VERSION}.tar.gz /bitnami/blacksmith-sandox/mysql-${BUILD_VERSION}.tar.gz
RUN <<EOT bash
    set -ex
    cd /bitnami/blacksmith-sandox
    tar xf mysql-${BUILD_VERSION}.tar.gz

    mv mysql-server-mysql-${BUILD_VERSION} mysql-${BUILD_VERSION}
    cd mysql-${BUILD_VERSION}

    # Cleanup tests dir, we don't need them here, they're only slowing down builds.
    rm -rf mysql-test
    mkdir -p mysql-test/lib/My/SafeProcess
    touch mysql-test/CMakeLists.txt
    touch mysql-test/lib/My/SafeProcess/CMakeLists.txt

    cmake -DBUILD_CONFIG=mysql_release -DCMAKE_INSTALL_PREFIX=/opt/bitnami/mysql -DCMAKE_BUILD_TYPE=RelWithDebInfo \
     -DHANDLE_FATAL_SIGNALS=ON -DMYSQLX_GENERATE_DIR=/bitnami/blacksmith-sandox/mysql-${BUILD_VERSION}/plugin/x/generated \
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

RUN find /opt/bitnami/ -name "*.so*" -type f | xargs ${BUILD_ARCH}-linux-gnu-strip --strip-all
RUN find /opt/bitnami/ -executable -type f | xargs ${BUILD_ARCH}-linux-gnu-strip --strip-all || true

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
RUN cp /bitnami/blacksmith-sandox/mysql-${BUILD_VERSION}/LICENSE /opt/bitnami/mysql/licenses/mysql-${BUILD_VERSION}.txt
RUN echo "mysql-${BUILD_VERSION},GPL2,https://github.com/mysql/mysql-server/archive/refs/tags/mysql-${BUILD_VERSION}.tar.gz" > /opt/bitnami/mysql/licenses/gpl-source-links.txt

FROM docker.io/bitnami/minideb:bullseye as stage-0

COPY --link rootfs/ /
COPY --link --from=ghcr.io/bitcompat/gosu:1.14.0-bullseye-r1 /opt/bitnami/ /opt/bitnami/
COPY --link --from=ghcr.io/bitcompat/ini-file:1.4.5-bullseye-r1 /opt/bitnami/ /opt/bitnami/
COPY --link --from=builder /opt/bitnami/ /opt/bitnami/

RUN /opt/bitnami/scripts/mysql/postunpack.sh

FROM docker.io/bitnami/minideb:bullseye as stage-1

ARG BUILD_VERSION
ARG TARGETARCH
ENV HOME="/" \
    OS_ARCH="${TARGETARCH}" \
    OS_FLAVOUR="debian-11" \
    OS_NAME="linux" \
    APP_VERSION="8.0.30" \
    BITNAMI_APP_NAME="mysql" \
    PATH="/opt/bitnami/common/bin:/opt/bitnami/mysql/bin:/opt/bitnami/mysql/sbin:$PATH"

LABEL org.opencontainers.image.ref.name="${BUILD_VERSION}-debian-11-r1" \
      org.opencontainers.image.title="mysql" \
      org.opencontainers.image.version="${BUILD_VERSION}"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install required system packages and dependencies
COPY --from=stage-0 /opt/bitnami/ /opt/bitnami/
RUN <<EOT bash
    set -e
    install_packages acl ca-certificates curl gzip procps psmisc tar libaio1
    mkdir -p /docker-entrypoint-initdb.d /bitnami/mysql/data
    echo "" > /.mysqlsh
    chown 1001 /.mysqlsh
    chown -R 1001 /bitnami
EOT

EXPOSE 3306

USER 1001
ENTRYPOINT [ "/opt/bitnami/scripts/mysql/entrypoint.sh" ]
CMD [ "/opt/bitnami/scripts/mysql/run.sh" ]
