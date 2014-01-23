#!/bin/sh

. /etc/initrd.d/00-common.sh

shutdown_init() {
    # setup the shutdown chroot environment
    mkdir -p /run/initramfs
    cp -r /bin /etc /lib /lib64 /sbin /run/initramfs
    for i in dev proc run sys; do
        mkdir /run/initramfs/$i
    done

    # save some space
    rm -r /run/initramfs/lib*/modules

    # copy the script to where systemd expects
    mkdir -p /run/initramfs/shutdown.d
    cp /etc/initrd.shutdown /run/initramfs/shutdown
    chmod u+x /run/initramfs/shutdown
}