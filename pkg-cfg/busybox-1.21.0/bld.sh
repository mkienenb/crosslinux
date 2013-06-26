#!/bin/${cl_bash}


# This file is part of the crosslinux software.
# The license which this software falls under is GPLv2 as follows:
#
# Copyright (C) 2013-2013 Douglas Jerome <douglas@crosslinux.org>
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place, Suite 330, Boston, MA  02111-1307  USA


# ******************************************************************************
# Definitions
# ******************************************************************************

PKG_URL="http://www.busybox.net/downloads/"
PKG_ZIP="busybox-1.21.0.tar.bz2"
PKG_SUM=""

PKG_TAR="busybox-1.21.0.tar"
PKG_DIR="busybox-1.21.0"


# ******************************************************************************
# pkg_patch
# ******************************************************************************

pkg_patch() {
PKG_STATUS=""
return 0
}


# ******************************************************************************
# pkg_configure
# ******************************************************************************

pkg_configure() {
cp --archive "${PKG_DIR}" "${PKG_DIR}-suid"
PKG_STATUS=""
return 0
}


# ******************************************************************************
# pkg_make
# ******************************************************************************

pkg_make() {

local cfgDir="${CROSSLINUX_PKGCFG_DIR}/$1"
local cfg=""
local SKIP_STRIP_FLAG=""

if [[ x"${CONFIG_SITE_SCRIPTS:-}" == x"" ]]; then
	SKIP_STRIP_FLAG=y
fi

source "${CROSSLINUX_SCRIPT_DIR}/_xbt_env_set"

# *****                 *****
# ***** Build - No SUID *****
# *****                 *****

cd "${PKG_DIR}"

cfg="${cfgDir}/_bbox-stnd.cfg"
if [[ x"${CONFIG_BUSYBOX_HAS_LOSETUP:-}" == x"" ]]; then
	${cl_sed} --in-place ${cfg} \
		--expression='s/CONFIG_LOSETUP=y/# CONFIG_LOSETUP is not set/'
fi
cp "${cfg}" .config

PKG_STATUS="make error"
CFLAGS="${CONFIG_CFLAGS} --sysroot=${TARGET_SYSROOT_DIR}" \
PATH="${CONFIG_XBT_DIR}:${PATH}" make \
	--jobs=${NJOBS} \
	ARCH="${CONFIG_CPU_ARCH}" \
	CROSS_COMPILE="${CONFIG_XBT_NAME}-" \
	CONFIG_PREFIX=${TARGET_SYSROOT_DIR} \
	SKIP_STRIP=${SKIP_STRIP_FLAG} \
	V=1 || return 1

cd ".."

# *****                               *****
# ***** Build and Install - With SUID *****
# *****                               *****

cd "${PKG_DIR}-suid"

cfg="${cfgDir}/_bbox-suid.cfg"
cp "${cfg}" .config

PKG_STATUS="make error"
CFLAGS="${CONFIG_CFLAGS} --sysroot=${TARGET_SYSROOT_DIR}" \
PATH="${CONFIG_XBT_DIR}:${PATH}" make \
	--jobs=${NJOBS} \
	ARCH="${CONFIG_CPU_ARCH}" \
	CROSS_COMPILE="${CONFIG_XBT_NAME}-" \
	CONFIG_PREFIX=${TARGET_SYSROOT_DIR} \
	SKIP_STRIP=${SKIP_STRIP_FLAG} \
	V=1 || return 1

cd ..

source "${CROSSLINUX_SCRIPT_DIR}/_xbt_env_clr"

PKG_STATUS=""
return 0

}


# ******************************************************************************
# pkg_install
# ******************************************************************************

pkg_install() {

PKG_STATUS="install error"

source "${CROSSLINUX_SCRIPT_DIR}/_xbt_env_set"

cd "${PKG_DIR}"
PKG_STATUS="make install error"
# CFLAGS, ARCH and CROSS_COMPILE seem to be needed to make install.
# Change the location of awk.
#
CFLAGS="${CONFIG_CFLAGS}  --sysroot=${TARGET_SYSROOT_DIR}" \
PATH="${CONFIG_XBT_DIR}:${PATH}" make \
	ARCH="${CONFIG_CPU_ARCH}" \
	CROSS_COMPILE="${CONFIG_XBT_NAME}-" \
	CONFIG_PREFIX=${TARGET_SYSROOT_DIR} \
	install || return 1
mv "${TARGET_SYSROOT_DIR}/usr/bin/awk" "${TARGET_SYSROOT_DIR}/bin/awk"
cd ..

cd "${PKG_DIR}-suid"
# Install busybox suid files.
#
rm --force "${TARGET_SYSROOT_DIR}/bin/busybox-suid"
rm --force "${TARGET_SYSROOT_DIR}/bin/mount"
rm --force "${TARGET_SYSROOT_DIR}/bin/ping"
rm --force "${TARGET_SYSROOT_DIR}/bin/su"
rm --force "${TARGET_SYSROOT_DIR}/bin/umount"
rm --force "${TARGET_SYSROOT_DIR}/usr/bin/crontab"
rm --force "${TARGET_SYSROOT_DIR}/usr/bin/passwd"
rm --force "${TARGET_SYSROOT_DIR}/usr/bin/traceroute"
_bbsuid="${TARGET_SYSROOT_DIR}/bin/busybox-suid"
${cl_install} --mode=4711 --owner=0 --group=0 busybox "${_bbsuid}"
link "${_bbsuid}" "${TARGET_SYSROOT_DIR}/bin/mount"
link "${_bbsuid}" "${TARGET_SYSROOT_DIR}/bin/ping"
link "${_bbsuid}" "${TARGET_SYSROOT_DIR}/bin/su"
link "${_bbsuid}" "${TARGET_SYSROOT_DIR}/bin/umount"
link "${_bbsuid}" "${TARGET_SYSROOT_DIR}/usr/bin/crontab"
link "${_bbsuid}" "${TARGET_SYSROOT_DIR}/usr/bin/passwd"
link "${_bbsuid}" "${TARGET_SYSROOT_DIR}/usr/bin/traceroute"
unset _bbsuid
cd ..

source "${CROSSLINUX_SCRIPT_DIR}/_xbt_env_clr"

if [[ -d "rootfs/" ]]; then
	${cl_find} "rootfs/" ! -type d -exec touch {} \;
	cp --archive --force rootfs/* "${TARGET_SYSROOT_DIR}"
fi

for _issueFile in ${TARGET_SYSROOT_DIR}/etc/issue*; do
	if [[ -f "${_issueFile}" ]]; then
		_sedCmd="${cl_sed} --in-place ${_issueFile}"
		${_sedCmd} -e "s/CROSSLINUX_VERS/${CONFIG_RELEASE_VERS}/"
		${_sedCmd} -e "s/CROSSLINUX_NAME/${CONFIG_RELEASE_NAME}/"
		${_sedCmd} -e "s/^.m/${CONFIG_CPU_ARCH}/"
		unset _sedCmd
	fi
done; unset _issueFile

_modprobeFile="${TARGET_SYSROOT_DIR}/etc/modprobe.d/modprobe.conf"
case "${CONFIG_BOARD}" in
	'mac_g4')
		sed --in-place "${_modprobeFile}" --expression="s/#nomac /# /"
		sed --in-place "${TARGET_SYSROOT_DIR}/etc/modtab" \
			--expression="s/# snd-powermac/snd-powermac/"
		;;
	*)
		sed --in-place "${_modprobeFile}" --expression="s/#nomac //"
		;;
esac
unset _modprobeFile

PKG_STATUS=""
return 0

}


# ******************************************************************************
# pkg_clean
# ******************************************************************************

pkg_clean() {
rm --force --recursive "${PKG_DIR}-suid"
PKG_STATUS=""
return 0
}


# end of file
