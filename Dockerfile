# syntax = docker/dockerfile:latest

## rclone build stage
## https://github.com/rclone/rclone/blob/master/Dockerfile
FROM golang AS builder

RUN \
  git clone https://github.com/rclone/rclone.git &&\
  cd rclone &&\
  git checkout v1.64.0 &&\
  CGO_ENABLED=0 \
  make
RUN /go/bin/rclone version

## borgbackup build
FROM python:3.12.2-alpine3.18 AS python_builder

RUN apk add --update --no-cache \
    # Runtime dependencies 
    bash \
    bash-completion \
    bash-doc \
    ca-certificates \
    curl \
    findmnt \
    fuse \
    libacl \
    logrotate \
    lz4-libs \
    mariadb-client \
    mariadb-connector-c \
    mongodb-tools \
    openssl1.1-compat \
    postgresql-client \
    sqlite \
    sshfs \
    supercronic \
    tzdata \
    # Build dependencies
    gcc \
    libc-dev \
    openssl-dev \
    lz4-dev \
    acl-dev \
    attr-dev \
    fuse-dev \
    linux-headers && \
    mkdir /wheel

COPY requirements.txt /
RUN pip wheel --wheel-dir=/wheel -r /requirements.txt

## final image build stage
## Original docker-borgmatic Dockerfile
FROM python:3.12.2-alpine3.18
LABEL maintainer='github.com/Pristavkin/docker-borgmatic-rclone'
LABEL org.opencontainers.image.description "borgmnatic-rclone docker image"
VOLUME /mnt/source
VOLUME /mnt/borg-repository
VOLUME /root/.borgmatic
VOLUME /etc/borgmatic.d
VOLUME /root/.config/borg
VOLUME /root/.ssh
VOLUME /root/.cache/borg

## todo: rclone docker image uses fuse3. Need to check if it is compatible with Borgmatic?
RUN apk add --update --no-cache \
    # Runtime dependencies 
    bash \
    bash-completion \
    bash-doc \
    ca-certificates \
    curl \
    findmnt \
    fuse \
    libacl \
    logrotate \
    lz4-libs \
    mariadb-client \
    mariadb-connector-c \
    mongodb-tools \
    openssl1.1-compat \
    postgresql-client \
    sqlite \
    sshfs \
    supercronic \
    tzdata && \
    rm -rf \
    /var/cache/apk/* \
    /.cache && \
    echo "user_allow_other" >> /etc/fuse.conf

## Install python packages from python_builder stage
RUN --mount=type=bind,from=python_builder,source=/,target=/python_builder \
    python3 -m pip install --find-links=file:///python_builder/wheel/ --no-cache -Ur /python_builder/requirements.txt && \
    borgmatic --version && \
    borgmatic --bash-completion > /usr/share/bash-completion/completions/borgmatic && echo "source /etc/bash/bash_completion.sh" > /root/.bashrc

## Copy rclone binary
COPY --from=builder /go/bin/rclone /usr/local/bin/
RUN rclone version && \
    rclone genautocomplete bash /usr/share/bash-completion/completions/rclone

COPY --chmod=755 entry.sh /entry.sh
ENTRYPOINT ["/entry.sh"]
