FROM docker as Docker

FROM quay.io/coreos/etcd:v3.4.5 as Etcd

FROM quay.io/piraeusdatastore/piraeus-client

# add runc
ENV RUNC_VER v1.0.0-rc10

RUN set -ex && \
    wget https://github.com/opencontainers/runc/releases/download/${RUNC_VER}/runc.amd64 && \
    install -v ./runc.amd64 /usr/bin/runc && \
    rm -vf ./runc.amd64

# add docker-cli
COPY --from=Docker /usr/local/bin/docker /usr/bin/docker

# add etcdctl
COPY --from=Etcd /usr/local/bin/etcdctl /usr/bin/

# add kubectl
ENV KUBE_VER=v1.18.0

RUN set -x && \
    wget https://storage.googleapis.com/kubernetes-release/release/${KUBE_VER}/bin/linux/amd64/kubectl && \
    install -v ./kubectl /usr/bin/ && \
    rm -vf ./kubectl

# add tools
RUN set -x && \
    apt-get update && \
    apt-get install -y curl jq gettext-base kmod util-linux && \
    apt-get clean

# add scripts
COPY tmpl /tmpl

COPY entry.sh /usr/bin/

ENTRYPOINT [ "entry.sh" ]