# OCI Monitor Pod for Piraeus

## Design Principle
The workflow does a `best effort` to register each node (with its default pool) to the controller. But no registration failure shall block the node process to come up. Users may use `linstor node` command sets to fix the registration manually.

## Workflow

### DRBD and tools on the host
On the node hosts, install following rpm or deb:
1. `kmod-drbd9.rpm/deb`
2. `drbd-utils.rpm/deb`
3. `drbd-top.rpm/deb`

### Controller
1. wait for etcd to come up by `curl <etcd_url>:2379` for json output of `health`
1. drop systemd file to `/etc/systemd/system/piraeus-controller.service`
1. drop runc binary to `/opt/piraeus/bin/runc`
1. add k8s envs to `/opt/piraeus/controller/oci/config.json`
1. drop /etc/resolv.conf to `/opt/piraeus/controller/oci/resolv.conf`
1. drop oci config to `/opt/piraeus/controller/oci/config.json`
1. drop oci rootfs to `/opt/piraeus/controller/oci/rootfs` by `docker export $( docker create )` or by overriding entrypoint:
    ```
    docker run --rm \
    -v /var/lib/piraeus/controller/oci/rootfs:/drop
    --entrypoint cp \
    piruaes-server \
    /* /drop
    ```
1. drop client script to `/opt/piraeus/client/linstor.sh`
    ```
    cat > /opt/piraeus/client/linstor.sh <<'EOF'
    /opt/piraeus/bin/runc exec -it piraeus-controller \
    linstor --no-utf8 $@
    EOF
    ```
1. `systemctl enable --now piraeus-controller`
1. monitor controller status by k8s `readiness probe` to `http:3370`
```
        readinessProbe:
          successThreshold: 3
          failureThreshold: 3
          httpGet:
            port: 3370
          periodSeconds: 5
```

### Node
1. wait for controller to come up by `curl <controller_url>:3370` for http reply
1. register node to controller: it will come up in `OFFLINE` status
1. drop systemd file to `/etc/systemd/system/piraeus-satellite.service`
1. drop runc binary to `/opt/piraeus/bin/runc`
1. add k8s envs to `/opt/piraeus/satellite/oci/config.json`
1. drop /etc/resolv.conf to `/opt/piraeus/satellite/oci/resolv.conf`
1. drop oci config to `/opt/piraeus/satellite/oci/config.json`
1. drop oci rootfs to `/opt/piraeus/satellite/oci/rootfs` by `docker export $( docker create )`
1. drop client script to `/opt/piraeus/client/linstor.sh`
1. `systemctl enable --now piraeus-satellite`
1. wait for node to enter `ONLINE` status by `curl <controller_url>:3370` for json output of `node list`
1. add `/var/lib/piraeus/storagepools/DfltStorPool` to a fileThin backend pool called `DfltStorPool` 
1. monitor node status by k8s `readiness probe` to `tcp:3366`
```
        readinessProbe:
          successThreshold: 3
          failureThreshold: 3
          tcpSocket:
            port: 3366
          periodSeconds: 5
```