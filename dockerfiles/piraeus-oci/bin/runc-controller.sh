#!/bin/bash -x

source lib.runc.sh

# get etcd endpoints from linstor.toml
echo Etcd endpoints are:
echo -e "${ETCD_ENDPOINTS/,/\n}"
 
# wait until etcd is up 
SECONDS=0
while [ "${SECONDS}" -lt '3600' ];  do
    for i in $( echo "${ETCD_ENDPOINTS}" | tr ',' '\n' ); do # Considering multiple etcd addresses
        if  _etcd_is_healthy "$i" ; then
            echo ...etcd is healthy
            break 2
        else
            echo ...etcd is NOT healthy
        fi
    done
    sleep 0.5
done

# set up etcd
echo "* Set up etcd in /etc/linstor/linstor.toml:"
cat > /etc/linstor/linstor.toml << EOF
[db]
connection_url = "etcd://${ETCD_ENDPOINTS}"
EOF
cat /init/etc/linstor/linstor.toml

# install runc
_install_runc controller

# main loop
set +x
trap 'exit 0' SIGTERM SIGINT
while true; do
    sleep 5
done