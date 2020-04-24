#!/bin/bash -x

source lib.runc.sh

# install kmod
_install_kmod

# install runc
_install_runc satellite

# edit drbd.conf
cat > /etc/drbd.conf << 'EOF'
include "/etc/drbd.d/*.res";
include "/var/lib/linstor.d/*.res";
EOF

# drop drbdadm script
mkdir -vp /opt/piraeus/bin
cat > /opt/piraeus/bin/drbdadm << 'EOF'
#!/bin/sh
/opt/piraeus/bin/runc exec -t piraeus-satellite \
drbdadm $@
EOF
chmod +x /opt/piraeus/bin/drbdadm
_host ln -fs /opt/piraeus/bin/drbdadm /usr/local/bin/drbdadm

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

# start runc
_start_runc satellite

# register node to cluster
[[ "$( linstor --machine node list --node "$NODE_NAME" | jq -r '.[0].nodes[0]' )" == 'null' ]] && \
linstor node create --node-type Satellite "$NODE_NAME" "$NODE_IP"


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