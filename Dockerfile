# syntax=docker/dockerfile:1
#
# Howell Technology rebuild of KSOPS (viaduct-ai/kustomize-sops). This file
# replaces upstream's Dockerfile, which is kept as Dockerfile.upstream.
# Changes from upstream:
#   - newer Go toolchain and Go dependencies (see README.md)
#   - only the ksops binary: no kustomize, no git, no shell
#   - static distroless base, every base image pinned by digest
#
# The binary sits at /usr/local/bin/ksops, as in upstream's image, so
# `ksops install <dir>` init containers work unchanged.

ARG GO_IMAGE=golang:1.26.11-bookworm@sha256:ea47ee45f1284d60f9cc09cb2c3bb4f508c256b640bd8bb30342ff13d1adcb52
ARG RUNTIME_IMAGE=gcr.io/distroless/static:nonroot@sha256:8ce6dd87e9823c5b48dcfb2c8604714ccb351ce59607327bcc4957448da279b5

FROM --platform=$BUILDPLATFORM ${GO_IMAGE} AS build
WORKDIR /src
ENV CGO_ENABLED=0 GOTOOLCHAIN=local
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download && go mod verify
COPY *.go ./
ARG TARGETOS TARGETARCH
RUN --mount=type=cache,target=/go/pkg/mod --mount=type=cache,target=/root/.cache/go-build \
    GOOS=$TARGETOS GOARCH=$TARGETARCH go build -trimpath -ldflags="-w -s" -o /out/ksops .

FROM ${RUNTIME_IMAGE}
LABEL org.opencontainers.image.source="https://github.com/Howell-Technology/ksops-image" \
      org.opencontainers.image.description="KSOPS v4.5.1 rebuilt with patched Go dependencies (unofficial)" \
      org.opencontainers.image.licenses="Apache-2.0"
COPY --from=build --chown=root:root --chmod=755 /out/ksops /usr/local/bin/ksops
COPY --from=build --chown=root:root --chmod=755 /out/ksops /usr/local/bin/kustomize-sops
USER nonroot
ENTRYPOINT ["/usr/local/bin/ksops"]
