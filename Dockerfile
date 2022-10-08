# syntax=docker/dockerfile:1.4

ARG KAFKA_VERSION
ARG SCALA_VERSION

FROM docker.io/bitnami/minideb:bullseye as builder

COPY --link --from=ghcr.io/bitcompat/render-template:1.0.3 /opt/bitnami/ /opt/bitnami/
COPY --link --from=ghcr.io/bitcompat/gosu:1.14.0 /opt/bitnami/ /opt/bitnami/
COPY --link --from=ghcr.io/bitcompat/wait-for-port:1.0.3-bullseye-r1 /opt/bitnami/ /opt/bitnami/
COPY --link --from=ghcr.io/bitcompat/java:11.0.16.1-1-bullseye-r1 /opt/bitnami/java/ /opt/bitnami/java/

ARG JAVA_EXTRA_SECURITY_DIR="/bitnami/java/extra-security"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY --link prebuildfs /
COPY --link rootfs /
RUN install_packages ca-certificates curl gzip tar

ARG SCALA_VERSION
ARG KAFKA_VERSION

RUN <<EOT bash
    set -eux
    mkdir -p /opt/src
    cd /opt/src
    curl -fsSL -o kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz https://archive.apache.org/kafka/${KAFKA_VERSION}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz ||
      curl -fsSL -o kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz https://downloads.apache.org/kafka/${KAFKA_VERSION}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz
    tar -xzf kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz

    mv kafka_${SCALA_VERSION}-${KAFKA_VERSION} /opt/bitnami/kafka
    chmod g+rwX /opt/bitnami
    chown 1001:1001 -R /opt/bitnami/kafka
    /opt/bitnami/scripts/java/postunpack.sh
    /opt/bitnami/scripts/kafka/postunpack.sh

    mv /opt/bitnami/kafka/LICENSE /opt/bitnami/kafka/licenses/kafka-${KAFKA_VERSION}.txt
EOT

FROM docker.io/bitnami/minideb:bullseye as stage-0

COPY --link --from=builder /opt/bitnami /opt/bitnami

RUN <<EOT bash
    install_packages acl ca-certificates curl gzip libc6 procps tar zlib1g
    mkdir -p /bitnami/kafka/config
    mkdir -p /bitnami/kafka/data
    mkdir -p /docker-entrypoint-initdb.d

    ln -sv /opt/bitnami/scripts/kafka/entrypoint.sh /entrypoint.sh
    ln -sv /opt/bitnami/scripts/kafka/run.sh /run.sh
EOT

LABEL org.opencontainers.image.ref.name="${SERVER_VERSION}-debian-11-r1" \
      org.opencontainers.image.title="kafka" \
      org.opencontainers.image.version="${SERVER_VERSION}"

ARG TARGETARCH
ENV HOME="/" \
    OS_ARCH="${TARGETARCH}" \
    OS_FLAVOUR="debian-11" \
    OS_NAME="linux" \
    APP_VERSION="${SERVER_VERSION}" \
    BITNAMI_APP_NAME="kafka" \
    JAVA_HOME="/opt/bitnami/java" \
    PATH="/opt/bitnami/java/bin:/opt/bitnami/common/bin:/opt/bitnami/kafka/bin:$PATH"

EXPOSE 9092
USER 1001
ENTRYPOINT [ "/opt/bitnami/scripts/kafka/entrypoint.sh" ]
CMD [ "/opt/bitnami/scripts/kafka/run.sh" ]
