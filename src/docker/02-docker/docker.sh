#!/bin/bash
set -x -e

TLS_PATH=/etc/docker/tls
CGROUPS="perf_event net_cls freezer devices blkio memory cpuacct cpu cpuset"

mkdir -p /sys/fs/cgroup
mount -t tmpfs none /sys/fs/cgroup

for i in $CGROUPS; do
    mkdir -p /sys/fs/cgroup/$i
    mount -t cgroup -o $i none /sys/fs/cgroup/$i
done

if ! lsmod | grep -q br_netfilter; then
    modprobe br_netfilter 2>/dev/null || true
fi

rm -f /var/run/docker.pid

ARGS=$(echo $(ros config get user_docker.args | sed 's/^-//'))
ARGS="$ARGS $(echo $(ros config get user_docker.extra_args | sed 's/^-//'))"

if [ "$(ros config get user_docker.tls)" = "true" ]; then
    ARGS="$ARGS $(echo $(ros config get user_docker.tls_args | sed 's/^-//'))"
    ros tls generate --server -d $TLS_PATH
    cd $TLS_PATH
fi

if [ -e /var/lib/rancher/conf/docker ]; then
    source /var/lib/rancher/conf/docker
fi

exec $ARGS $DOCKER_OPTS >/var/log/docker.log 2>&1
