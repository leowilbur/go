FROM alpine:3.13


RUN apk add --no-cache \
    ca-certificates

ENV PATH /usr/local/go/bin:$PATH

ENV GOLANG_VERSION 1.16.3

COPY ./ /usr/local

RUN set -eux; \
    apk add --no-cache --virtual .build-deps \
    bash \
    gcc \
    gnupg \
    go \
    musl-dev \
    openssl \
    ; \
    apkArch="$(apk --print-arch)"; \
    case "$apkArch" in \
    'x86_64') \
    export GOARCH='amd64' GOOS='linux'; \
    ;; \
    'armhf') \
    export GOARCH='arm' GOARM='6' GOOS='linux'; \
    ;; \
    'armv7') \
    export GOARCH='arm' GOARM='7' GOOS='linux'; \
    ;; \
    'aarch64') \
    export GOARCH='arm64' GOOS='linux'; \
    ;; \
    'x86') \
    export GO386='softfloat' GOARCH='386' GOOS='linux'; \
    ;; \
    'ppc64le') \
    export GOARCH='ppc64le' GOOS='linux'; \
    ;; \
    's390x') \
    export GOARCH='s390x' GOOS='linux'; \
    ;; \
    *) echo >&2 "error: unsupported architecture '$apkArch' (likely packaging update needed)"; exit 1 ;; \
    esac; \
    \
    ( \
    cd /usr/local/go/src; \
    # set GOROOT_BOOTSTRAP + GOHOST* such that we can build Go successfully
    export GOROOT_BOOTSTRAP="$(go env GOROOT)" GOHOSTOS="$GOOS" GOHOSTARCH="$GOARCH"; \
    if [ "${GO386:-}" = 'softfloat' ]; then \
    # https://github.com/docker-library/golang/issues/359 -> https://github.com/golang/go/issues/44500
    # (once our Alpine base has Go 1.16, we can remove this hack)
    GO386= ./bootstrap.bash; \
    export GOROOT_BOOTSTRAP="/usr/local/go-$GOOS-$GOARCH-bootstrap"; \
    "$GOROOT_BOOTSTRAP/bin/go" version; \
    fi; \
    ./make.bash; \
    if [ "${GO386:-}" = 'softfloat' ]; then \
    rm -rf "$GOROOT_BOOTSTRAP"; \
    fi; \
    ); \
    \
    apk del --no-network .build-deps; \
    \
    # pre-compile the standard library, just like the official binary release tarballs do
    go install std; \
    # go install: -race is only supported on linux/amd64, linux/ppc64le, linux/arm64, freebsd/amd64, netbsd/amd64, darwin/amd64 and windows/amd64
    #	go install -race std; \
    \
    # remove a few intermediate / bootstrapping files the official binary release tarballs do not contain
    rm -rf \
    /usr/local/go/pkg/*/cmd \
    /usr/local/go/pkg/bootstrap \
    /usr/local/go/pkg/obj \
    /usr/local/go/pkg/tool/*/api \
    /usr/local/go/pkg/tool/*/go_bootstrap \
    /usr/local/go/src/cmd/dist/dist \
    ; \
    \
    go version

ENV GOPATH /go
ENV PATH $GOPATH/bin:$PATH
RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"
WORKDIR $GOPATH