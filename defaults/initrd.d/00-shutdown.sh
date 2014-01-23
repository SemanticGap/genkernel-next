#!/bin/sh

. /etc/initrd.d/00-common.sh

shutdown_init() {
    mkdir -p /run/initramfs/shutdown.d
    cp /etc/initrd.shutdown /run/initramfs/shutdown
    chmod u+x /run/initramfs/shutdown
}