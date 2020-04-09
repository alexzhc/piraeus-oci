#!/bin/sh

_host() { 
    nsenter -t1 -m "$@" 
}

_install_runc() {
    component="$1"

    # stop node systemd
    _host systemctl disable --now piraeus-"$component".service

    # install runc
    mkdir -vp /opt/piraeus/bin
    cp -vuf /usr/bin/runc "/opt/piraeus/bin/"

    # create oci dir
    oci_dir=/opt/piraeus/"$component"/oci
    rm -fr "$oci_dir"
    rootfs_dir="${oci_dir}/rootfs"
    mkdir -vp "$rootfs_dir"

    # install oci config
    ENV="$( printenv | sed 's/^/"/; s/$/",/' )"
    export ENV
    envsubst < /oci/"$component".config.json | jq '.' > "${oci_dir}/config.json"

    # install oci rootfs
    container_id="$( docker create "$SERVER_IMG" )"
    docker export "$container_id" | tar -C "$rootfs_dir" --checkpoint=600 --checkpoint-action=exec='printf "\b=>"' -xf -
    echo
    docker rm -f "$container_id"

    # install resolv.conf
    cp -vf /etc/resolv.conf "${oci_dir}/"

    # drop client script
    mkdir -vp /opt/piraeus/client 
    cat > /opt/piraeus/client/linstor <<EOF
#!/bin/sh
/opt/piraeus/bin/runc exec -t piraeus-${component} \
linstor --no-utf8 \$@
EOF

    # install systemd
    cp -vuf /oci/"$component".service /etc/systemd/system/piraeus-"$component".service

    # start systemd
    _host systemctl daemon-reload
    _host systemctl enable --now piraeus-"$component".service

}

_curl () {
    curl -Ss --connect-timeout 1 --retry 3 --retry-delay 0 "$@"
}

_etcd_is_healthy() {
    [[ "$( _curl "$1"/health | jq -r '.health' )" == 'true' ]]
}