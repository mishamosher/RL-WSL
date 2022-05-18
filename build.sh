#!/bin/bash

# Environment variables for the Rocky Linux cloud image
ARCH="x86_64"
OS_MAJOR_VER="8"
OS_FULL_VER="8.6"
ROOTFS_VER="8.6-20220515"
ROOTFS_FN="Rocky-${OS_MAJOR_VER}-GenericCloud-${ROOTFS_VER}.${ARCH}.qcow2"
ROOTFS_URL="https://dl.rockylinux.org/pub/rocky/${OS_FULL_VER}/images/${ROOTFS_FN}"

# Environment variables for Yuk7's wsldl
LNCR_BLD="22020900"
LNCR_ZIP="icons.zip"
LNCR_NAME="Rocky"
LNCR_FN=${LNCR_NAME}.exe
LNCR_ZIPFN=${LNCR_NAME}${OS_MAJOR_VER}.exe
LNCR_URL="https://github.com/yuk7/wsldl/releases/download/${LNCR_BLD}/${LNCR_ZIP}"

# Waits until a file appears or disappears
# - $1   File path to wait for its existence
# - [$2] The string 'a' (default) to wait until the file appears, or 'd' to wait until the file disappears
# - [$3] Timeout in seconds
waitFile() {
  local START
  START=$(cut -d '.' -f 1 /proc/uptime)
  local MODE=${2:-"a"}
  until [[ "${MODE}" = "a" && -e "$1" ]] || [[ "${MODE}" = "d" && ( ! -e "$1" ) ]]; do
    sleep 1s
    if [ -n "$3" ]; then
      local NOW
      NOW=$(cut -d '.' -f 1 /proc/uptime)
      local ELAPSED=$(( NOW - START ))
      if [ $ELAPSED -ge "$3" ]; then break; fi
    fi
  done
  sleep 2s
}

# Create a work dir
mkdir wsl
cd wsl

# Download the Rocky Linux cloud image and Yuk7's WSLDL
wget --no-verbose ${ROOTFS_URL} -O ${ROOTFS_FN}
wget --no-verbose ${LNCR_URL} -O ${LNCR_ZIP}

# Extract the Rocky Linux WSL launcher
unzip ${LNCR_ZIP} ${LNCR_FN}

# Clean up
rm ${LNCR_ZIP}

# Mount the qcow2 image
sudo mkdir mntfs
sudo modprobe nbd
sudo qemu-nbd -c /dev/nbd0 --read-only ./${ROOTFS_FN}
waitFile /dev/nbd0p3 "a" 30
sudo mount -o ro /dev/nbd0p3 mntfs

# Clone the qcow2 image contents to a writable directory
sudo cp -a mntfs rootfs

# Unmount the qcow2 image
sudo umount mntfs
sudo qemu-nbd -d /dev/nbd0
waitFile /dev/nbd0p3 "d" 30
sudo rmmod nbd
sudo rmdir mntfs

# Clean up
rm ${ROOTFS_FN}

# Create a tar.gz of the rootfs
sudo tar -zcpf rootfs.tar.gz -C ./rootfs .
sudo chown "$(id -un)" rootfs.tar.gz

# Clean up
sudo rm -rf rootfs

# Create the distribution zip of WSL Rocky Linux
mkdir out
mkdir dist
mv -f ${LNCR_FN} ./out/${LNCR_ZIPFN}
mv -f rootfs.tar.gz ./out/
pushd out
zip ../dist/RL${OS_MAJOR_VER}.zip ./*
popd

# Clean up
rm -rf out
