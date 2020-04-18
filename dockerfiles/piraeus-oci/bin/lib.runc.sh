#!/bin/bash

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

    # replace lvm binary with nsenter
if [ "$MAP_HOST_LVM" = 'true' ]; then
    lvmpath="${rootfs_dir}/sbin/lvm"
    mv -vf "$lvmpath" "${lvmpath}.distro"
    cat > "$lvmpath" <<'EOF'
#!/bin/sh
nsenter --target 1 --mount -- "$(basename $0)" "$@"
EOF
    chmod +x "$lvmpath"
fi

    # drop client script
    mkdir -vp /opt/piraeus/client 
    cat > /opt/piraeus/client/linstor <<EOF
#!/bin/sh
/opt/piraeus/bin/runc exec -t piraeus-${component} \
linstor --no-utf8 \$@
EOF

    # install systemd
    cp -vuf /oci/"$component".service /etc/systemd/system/piraeus-"$component".service
}

_start_runc() {
    component="$1"
    # start systemd
    _host systemctl daemon-reload
    _host systemctl enable --now piraeus-"$component".service
    _host journalctl -fu piraeus-"$component".service &
}

_curl() {
    curl -Ss --connect-timeout 1 --retry 3 --retry-delay 0 "$@"
}

_etcd_is_healthy() {
    [[ "$( _curl "$1"/health | jq -r '.health' )" == 'true' ]]
}

_install_kmod() {
    echo '* Enable dm_thin_pool'
    lsmod | grep -q ^dm_thin_pool || modprobe dm_thin_pool
    lsmod | grep -E '^dm_thin_pool|^Module'

    # compile and install drbd kernel module
    if lsmod | grep -q drbd ; then
        echo 'DRBD module is already loaded'
        lsmod | grep -E '^drbd|^Module'
        modinfo drbd || echo "* WARN: DRBD binary is missing"
    elif [[ "v$( modinfo drbd | awk '/^version: / {print $2}' )" == "${DRBD_IMG_TAG}-1" ]] ; then
        echo "* Load drbd module version \"${DRBD_IMG_TAG}\""
        modprobe drbd
        modprobe drbd_transport_tcp
        lsmod | grep -E '^drbd|^Module'
        modinfo drbd
    elif [[ ${DRBD_IMG_TAG,,} == 'none' ]]; then
        echo '* Skip drbd installation'
    else
        # find image name according to linux distribution
        if [[ "$( uname -r )" =~ el7 ]]; then
            drbd_image_name=drbd9-centos7
        elif [[ "$( uname -r )" =~ el8 ]]; then
            drbd_image_name=drbd9-centos8
        elif [[ "$( uname -a )" =~ Ubuntu ]]; then
            drbd_image_name=drbd9-bionic
            [[ "$( uname -r )" =~ 4\.15\. ]] && mount_usr_lib='true'
        fi
        # run drbd9 driver loader
        drbd_image_url="${DRBD_IMG_REPO}/${drbd_image_name}:${DRBD_IMG_TAG}"
        echo "* Compile and load drbd module by image \"${drbd_image_url}\""
        if [[ "${DRBD_IMG_PULL_POLICY,,}" == "always" ]] || [[ "$( _docker_image_inspect "$drbd_image_url" | jq '.Id' )" == "null" ]]; then
            docker pull "$drbd_image_url"
        fi

        if [[ "$mount_usr_lib" == "true" ]]; then
            docker run --rm \
                --privileged \
                -e LB_INSTALL=yes \
                -v /lib/modules:/lib/modules \
                -v /usr/src:/usr/src:ro \
                -v /usr/lib:/usr/lib:ro \
                "$drbd_image_url"
        else
            docker run --rm \
                --privileged \
                -e LB_INSTALL=yes \
                -v /lib/modules:/lib/modules \
                -v /usr/src:/usr/src:ro \
                "$drbd_image_url"
        fi
    fi
}