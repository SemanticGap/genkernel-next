#!/bin/sh

. /etc/initrd.d/00-common.sh
. /etc/initrd.d/00-splash.sh

AUFS_MNT_ROOT="/run/aufs"

is_aufs_root() {
	if [ -b "${AUFS_ROOT}" ]; then
		return 0
	else
		return 1
	fi
}

aufs_root_init() {
	is_aufs_root || return 0

	good_msg "Mounting overlay file system ${AUFS_ROOT}"

	mkdir -p ${AUFS_MNT_ROOT}/rw ${AUFS_MNT_ROOT}/ro

	mount -oremount,rw /newroot
	mount -omove /newroot ${AUFS_MNT_ROOT}/rw

	mount "${AUFS_ROOT}" ${AUFS_MNT_ROOT}/ro

	mount -t aufs none /newroot -o dirs=${AUFS_MNT_ROOT}/rw=rw:${AUFS_MNT_ROOT}/ro=ro

  aufs_root_install_shutdown_hook
}

aufs_root_install_shutdown_hook() {
    ln -s /etc/shutdown.d/99-aufsroot.sh /run/initramfs/shutdown.d/99-aufsroot.sh
}