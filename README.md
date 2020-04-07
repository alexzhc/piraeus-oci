# OCI Monitor Pod for Piraeus

## Workflow

### Controller
1. wait for etcd to come up by curl etcd_url:2379 for json output of `health`
1. drop systemd file to /etc/systemd/system/piraeus-controller.service
1. drop runc binary to /opt/piraeus/bin/runc
1. add k8s envs to /opt/piraeus/controller/oci/config.json
1. drop oci config to /opt/piraeus/controller/oci/config.json
1. drop oci rootfs to /opt/piraeus/controller/oci/rootfs by `docker export $( docker create )`
1. drop client script to /opt/piraeus/client/linstor.sh
1. systemctl enable --now piraeus-controller
1. monitor controller status by k8s readiness probe to http:3370

### Node
1. wait for controller to come up by `curl controller_url:3370` for http reply
1. register node to controller: it will come up in `OFFLINE` status
1. drop systemd file to /etc/systemd/system/piraeus-satellite.service
1. drop runc binary to /opt/piraeus/bin/runc
1. add k8s envs to /opt/piraeus/satellite/oci/config.json
1. drop oci config to /opt/piraeus/satellite/oci/config.json
1. drop oci rootfs to /opt/piraeus/satellite/oci/rootfs by `docker export $( docker create )`
1. drop client script to /opt/piraeus/client/linstor.sh
1. systemctl enable --now piraeus-satellite
1. wait for node to enter `ONLINE` status by `curl controller_url:3370` for json output of `node list`
1. add /var/lib/piraeus/storagepools/DfltStorPool to a fileThin backend pool called `DfltStorPool` 
1. monitor node status by k8s readiness probe to tcp:3366

### DRBD and other tools on the host
On the node hosts, install following rpm or deb:
1. drbd9.rpm/deb
2. drbd-utils.rpm/deb
3. drbd-top.rpm/deb