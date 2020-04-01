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
_host systemctl disable --now piraeus-satellite.service

# install runc
mkdir -vp /opt/piraeus/bin
cp -vuf /usr/bin/runc "/opt/piraeus/bin/"

# create oci dir
oci_dir=/opt/piraeus/satellite/oci
rm -fr "$oci_dir"
rootfs_dir="${oci_dir}/rootfs"
mkdir -vp "$rootfs_dir"

# install oci config
ENV="$( printenv | sed 's/^/"/; s/$/",/' )"
export ENV
envsubst < /oci/satellite.config.json | jq '.' > "${oci_dir}/config.json"

# install oci rootfs
container_id="$( docker create "$SERVER_IMG" )"
_host sh -c "docker export "$container_id" | tar -C "$rootfs_dir" --checkpoint=100 --checkpoint-action=exec='printf .' -xf -"
echo
_host docker rm -f "$container_id"

# install resolv.conf
cp -vf /etc/resolv.conf "${oci_dir}/"

# install systemd
cp -vuf /oci/satellite.service /etc/systemd/system/piraeus-satellite.service

# start systemd
_host systemctl daemon-reload
_host systemctl enable --now piraeus-satellite.service

# add default storage pool
SECONDS=0
while [ "${SECONDS}" -lt '3600' ];  do
    if [[ "$( linstor --machine node list --node "$NODE_NAME" | jq '.[0].nodes[0].connection_status' )" == '2' ]]; then
        echo '... this node is ONLINE'
        break
    else
        echo '... this node is OFFLINE'
    fi
    sleep 1
done

pool_name=DfltStorPool
pool_dir="${POOL_BASE_DIR}/${pool_name}"
mkdir -vp "$pool_dir"
[[ "$( linstor --machine storage-pool list -n "$NODE_NAME" -s "$pool_name" | jq -r '.[0].stor_pools[0]' )" == 'null' ]] && \
linstor storage-pool create filethin "$NODE_NAME" "$pool_name" "$pool_dir"

# main loop
set +x
trap 'exit 0' SIGTERM SIGINT
while true; do
    sleep 5
done