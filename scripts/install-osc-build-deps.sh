#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Bryan Richter
#
# SPDX-License-Identifier: Apache-2.0

#
# Provision an Ubuntu container with osc + the virtualization stack `osc build`
# needs: KVM for native builds and qemu for cross-arch.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
ln -fs /usr/share/zoneinfo/Etc/UTC /etc/localtime

apt-get update
apt-get -y install gpg curl
echo 'deb http://download.opensuse.org/repositories/openSUSE:/Tools/xUbuntu_24.04/ /' \
    > /etc/apt/sources.list.d/openSUSE-Tools.list
curl -fsSL https://download.opensuse.org/repositories/openSUSE:/Tools/xUbuntu_24.04/Release.key \
    | gpg --dearmor > /etc/apt/trusted.gpg.d/openSUSE-Tools.gpg
apt-get update

deps=(
    osc git                                     # the build tool
    xz-utils python3-zstandard zstd binutils    # unpack the virtualized buildroot
    qemu-system-x86 linux-image-generic         # KVM (native builds)
    qemu-system-arm qemu-user-static            # cross-arch emulation
)
# shellcheck disable=SC2068
apt-get -y install ${deps[@]}

# osc looks for the initrd at /boot/initrd.
ln -sf /boot/initrd.img /boot/initrd
