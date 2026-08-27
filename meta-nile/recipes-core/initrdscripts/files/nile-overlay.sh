#!/bin/sh

# SPDX-License-Identifier: MIT
#
# Copyright 2026 (C), National Instruments

# initramfs module intended to mount NILE's read-write /data partition
# as an overlay on top of /, keeping the original rootfs read-only.
#
# This works a bit differently from the `overlayroot` module in the
# initramfs framework:
# - we know what partitions we're looking for, so we do not need
#   additional kernel cmdline options

PATH=/sbin:/bin:/usr/sbin:/usr/bin

# We're running after the "rootfs" module, so rootfs has already been mounted.
# This module is just responsible for the /data partition.

# We get OLDROOT from the rootfs module
OLDROOT="/rootfs"

NEWROOT="${RWMOUNT}/root"
RWMOUNT="/overlay"
ROMOUNT="${RWMOUNT}/rofs"
UPPER_DIR="${RWMOUNT}/upper"
WORK_DIR="${RWMOUNT}/work"

update_overlay_version_marker ()
{
	grep 'VERSION_ID=' ${OLDROOT}/etc/os-release > "${RWMOUNT}/rootfs-release"
}

# Factory reset unmounts the data partition, formats it, then remounts it.
factory_reset () {
	umount "${RWMOUNT}"
	info "reformatting user data partition"
	mkfs.ext4 -q -F -L "data" "${data_part_device}"

	if mount -n -o rw,sync,relatime "${data_part_device}" "${RWMOUNT}"; then
		info "remounted user data partition"
		update_overlay_version_marker
	fi
}

handle_overlay_upgrade () {
	info "clearing overlay changes to /usr"
	# clear changes to /usr
	rm -rf "${UPPER_DIR}/usr"
	# also clear changes to /etc/ipk-postinsts so on-target postinsts get rerun
	rm -rf "${UPPER_DIR}/etc/ipk-postinsts"

	update_overlay_version_marker
}

handle_overlay_downgrade () {
	msg "clearing all overlay changes"

	# TODO: should be data-driven?

	# On downgrade, we retain password data and ssh keys
	NEW_UPPER_DIR="${RWMOUNT}/.new_upper"
	rm -rf "${NEW_UPPER_DIR}"
	mkdir -p "${NEW_UPPER_DIR}" "${NEW_UPPER_DIR}/etc"
	for i in "/etc/passwd" "/etc/shadow" "/etc/shadow-" "/etc/group" "/etc/gshadow" "/etc/machine-id"; do
		if [ -e "${RWMOUNT}${i}" ]; then
			mv "${RWMOUNT}${i}" "${NEW_UPPER_DIR}${i}"
		fi
	done

	# wildcarded to allow for all key types
	mkdir -p "${NEW_UPPER_DIR}/etc/ssh"
	mv "${RWMOUNT}/etc/ssh/"ssh_*_key* "${NEW_UPPER_DIR}/etc/ssh"

	# home directories
	if [ -e "${RWMOUNT}/home" ]; then
		mv "${RWMOUNT}/home" "${NEW_UPPER_DIR}"
	fi

	# root's home directory
	if [ -e "${RWMOUNT}/root" ]; then
		mv "${RWMOUNT}/root" "${NEW_UPPER_DIR}"
	fi

	rm -rf "${UPPER_DIR}"
	mv "${NEW_UPPER_DIR}" "${UPPER_DIR}"

	update_overlay_version_marker
}

# udev has populated the /dev/disk tree.
# TODO: should probably check to ensure data partition is on same physical volume as rootfs?
#       (protects against someone with an external SD card called "data"...)
# TODO: should we also have a predefined UUID for "data" partition?
if [ -e /dev/disk/by-label/data ]; then
	data_part_device=/dev/disk/by-label/data
elif [ -e /dev/disk/by-partlabel/data ]; then
	data_part_device=/dev/disk/by-partlabel/data
else
	fatal "nile-overlay: unable to find data partition"
fi

mkdir -p ${RWMOUNT}

if mount -n -o rw,sync,relatime "${data_part_device}" "${RWMOUNT}"; then
	info "applying user data partition as overlay"

	# Factory reset
	# TODO: The way that we should be doing factory reset should align with systemd
	#       (https://systemd.io/FACTORY_RESET/), but scarthgap's systemd is too old
	#       to have this interface. Current implementation checks for /etc/factory-reset
	#       being present as a "factory reset is requested" signal.
	if [ -e "${UPPER_DIR}/etc/factory-reset" ]; then
		info "factory reset has been requested"
		factory_reset
	fi

	# compare the rootfs version with the overlay's associated rootfs-release
	ROOTFS_VER=$(grep -s 'VERSION_ID=' "${OLDROOT}/etc/os-release" | sed 's/.*=//;')
	OVERLAY_VER=$(grep -s 'VERSION_ID=' "${RWMOUNT}/rootfs-release" | sed 's/.*=//;')
	systemd-analyze compare-versions "${ROOTFS_VER}" "${OVERLAY_VER}" >/dev/null; CMP=$?
	if [ ${CMP} -eq 11 ]; then
		info "rootfs '${ROOTFS_VER}' > overlay '${OVERLAY_VER}'; we have upgraded"
		handle_overlay_upgrade
	elif [ ${CMP} -eq 12 ]; then
		info "rootfs '${ROOTFS_VER}' < overlay '${OVERLAY_VER}'; we have downgraded"
		handle_overlay_downgrade
	elif [ ${CMP} -eq 0 ]; then
		info "rootfs '${ROOTFS_VER}' == overlay '${OVERLAY_VER}'; same version"
	fi

	# Set up overlay directories
	mkdir -p "${UPPER_DIR}"
	mkdir -p "${WORK_DIR}"
	mkdir -p "${NEWROOT}"
	mkdir -p "${ROMOUNT}"

	# Remount OLDROOT as read-only
	mount -o bind "${OLDROOT}" "${ROMOUNT}"
	mount -o remount,ro "${ROMOUNT}"

	# Mount RW overlay
	mount -t overlay overlay -o "lowerdir=${ROMOUNT},upperdir=${UPPER_DIR},workdir=${WORK_DIR}" "${NEWROOT}" || fatal "nile-overlay: unable to mount overlay"
else
	fatal "nile-overlay: unable to mount data partition"

	# TODO: if we got to this point, the data partition does exist.
	# On failure here, should we reformat it and try again?
fi

# Set up filesystems on overlay
mkdir -p "${NEWROOT}/proc"
mkdir -p "${NEWROOT}/dev"
mkdir -p "${NEWROOT}/sys"
mkdir -p "${NEWROOT}/rofs"

mount -n --move "${ROMOUNT}" "${NEWROOT}/rofs"
mount -n --move "/proc" "${NEWROOT}/proc"
mount -n --move "/sys" "${NEWROOT}/sys"
mount -n --move "/dev" "${NEWROOT}/dev"

# Remove sync option from data mount in preparation for toggle
sync
mount -o remount,async "$RWMOUNT"

exec chroot "${NEWROOT}/" "${bootparam_init:-/sbin/init}" || fatal "Couldn't chroot into overlay"
