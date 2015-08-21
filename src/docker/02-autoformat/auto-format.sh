#!/bin/bash
set -ex

MAGIC=${MAGIC:-"boot2docker, please format-me"}

AUTOFORMAT=${AUTOFORMAT:-"/dev/sda /dev/vda"}
DEVS=(${AUTOFORMAT})
FORMATZERO=${FORMATZERO:-false}

for dev in ${DEVS[@]}; do
    if [ -b "${dev}" ]; then

        # Test for our magic string (it means that the disk was made by ./boot2docker init)
        HEADER=`dd if=${dev} bs=1 count=${#MAGIC} 2>/dev/null`
    
        if [ "$HEADER" = "$MAGIC" ]; then
            # save the preload userdata.tar file
            dd if=${dev} of=/userdata.tar bs=1 count=8192
        elif [ "${FORMATZERO}" != "true" ]; then
            # do not try to guess whether to auto-format a disk beginning with 1MB filled with 00
            continue
        elif ! od -A d -N 1048576 ${dev} | head -n 3 | diff ./od-1m0 - >/dev/null 2>&1; then
            # do not auto-format if the disk does not begin with 1MB filled with 00
            continue
        fi
    
        mkfs.ext4 -L RANCHER_STATE ${dev}
    
        if [ -e "/userdata.tar" ]; then
            mkdir -p /mnt/new-root
            mount -t ext4 ${dev} /mnt/new-root
            pushd /mnt/new-root
            mkdir -p ./var/lib/rancher/conf/cloud-config.d
            echo $(tar -xvf /userdata.tar)
            AUTHORIZED_KEY1=$(cat ./.ssh/authorized_keys)
            AUTHORIZED_KEY2=$(cat ./.ssh/authorized_keys2)
            tee ./var/lib/rancher/conf/cloud-config.d/machine.yml << EOF
#cloud-config

rancher:
 network:
  interfaces:
   eth0:
    dhcp: true
   eth1:
    dhcp: true
   lo:
    address: 127.0.0.1/8

ssh_authorized_keys:
 - ${AUTHORIZED_KEY1}
 - ${AUTHORIZED_KEY2} 

users:
 - name: docker
   ssh_authorized_keys:
   - ${AUTHORIZED_KEY1}
   - ${AUTHORIZED_KEY2}
EOF
            popd
            umount /mnt/new-root
        fi

        # do not check another device
        break
    fi
done
