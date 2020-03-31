#!/bin/bash -x

_host() {
    nsenter -t1 -m "$@"
}

# wait until controller is up
SECONDS=0
while [ "$SECONDS" -lt '3600' ];  do
    if curl -Ss --connect-timeout 2 "$LS_CONTROLLERS" | grep 'Linstor REST server'; then
        echo '... controller is UP'
        break
    else
        echo '... controller is DOWN'
    fi
    sleep 1
done

# register node to cluster
[[ "$( linstor --machine node list --node "$NODE_NAME" | jq -r '.[0].nodes[0]' )" == 'null' ]] && \
linstor node create --node-type Satellite "$NODE_NAME" "$NODE_IP"

# stop node systemd
_host systemctl disable --now piraeus-node.service

# install runc
oci_dir=/opt/piraeus/oci
rm -fr "${oci_dir}/node"
rootfs_dir="${oci_dir}/node/rootfs"
mkdir -vp "${oci_dir}/node/rootfs"
cp -vuf /usr/bin/runc "${oci_dir}/"

# install oci rootfs
container_id="$( docker create quay.azk8s.cn/piraeusdatastore/piraeus-server:v1.4.2 )"
_host bash -c "docker export "$container_id" | tar -C "$rootfs_dir" -xf -"
_host docker rm -f "$container_id"

# install oci config
ENV="$( printenv | sed 's/^/"/; s/$/",/' )"
export ENV
export ARGS='"/usr/share/linstor-server/bin/Satellite", "--logs=/var/log/linstor-satellite", "--config-directory=/etc/linstor", "--skip-hostname-check"'
envsubst < /tmpl/config.json | jq '.' > "${oci_dir}/node/config.json"

# install systemd
export COMPONENT=node
envsubst < /tmpl/.service > /etc/systemd/system/piraeus-node.service

# start systemd
_host systemctl daemon-reload
_host systemctl enable --now piraeus-node.service

# main loop
set +x
trap 'exit 0' SIGTERM SIGINT
while true; do
    sleep 2
done