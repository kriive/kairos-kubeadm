ARG BASE_IMAGE=ubuntu:24.04
ARG KUBEADM_VERSION=1.33.1

FROM quay.io/kairos/kairos-init:v0.5.1 AS kairos-init

# Build the provider binary
FROM golang:1.24-alpine AS provider-builder
RUN apk add --no-cache git
WORKDIR /workspace
RUN git clone https://github.com/kairos-io/provider-kubeadm.git .

RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o agent-provider-kubeadm .

FROM ${BASE_IMAGE} AS base-kairos
ARG MODEL=generic
ARG TRUSTED_BOOT=false
ARG VERSION=v0.0.1
ARG KUBEADM_VERSION
ARG TARGETPLATFORM

# Add AppArmor.
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates curl apparmor && \
    rm -rf /var/lib/apt/lists/*

COPY config.toml /etc/containerd/config.toml
COPY scripts/* /opt/kubeadm/scripts/
COPY setup-kube-admin.sh /setup-kube-admin.sh
COPY --from=provider-builder /workspace/agent-provider-kubeadm /system/providers/agent-provider-kubeadm

RUN /setup-kube-admin.sh
RUN rm /setup-kube-admin.sh

RUN --mount=type=bind,from=kairos-init,src=/kairos-init,dst=/kairos-init \
    /kairos-init -l debug -m "${MODEL}" -t "${TRUSTED_BOOT}" --version "${VERSION}" && \
    /kairos-init validate -t "${TRUSTED_BOOT}"