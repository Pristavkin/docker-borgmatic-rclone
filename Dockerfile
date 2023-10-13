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

## final image build stage
## Original docker-borgmatic Dockerfile
FROM python:3.11.5-alpine3.18
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
    tzdata &&\
    rm -rf \
    /var/cache/apk/* \
    /.cache &&\
    echo "user_allow_other" >> /etc/fuse.conf

COPY --chmod=755 entry.sh /entry.sh
COPY requirements.txt /

## Copy rclone binary
COPY --from=builder /go/bin/rclone /usr/local/bin/
RUN rclone version

RUN python3 -m pip install --no-cache -Ur requirements.txt
RUN borgmatic --bash-completion > /usr/share/bash-completion/completions/borgmatic && echo "source /etc/bash/bash_completion.sh" > /root/.bashrc

ENTRYPOINT ["/entry.sh"]
