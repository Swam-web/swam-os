#!/usr/bin/env bash

### Manettes Xbox : xone (dongle USB) et xpadneo (Bluetooth)
set -ouex pipefail

### Xbox controllers: xone (USB dongle) and xpadneo (Bluetooth)
## Out-of-tree modules, prebuilt against the CachyOS kernel: kmods are
## always tied to the kernel ABI, so they have to be built for this exact
## kernel (they are not in the Fedora or negativo17 repos either).

## xone
XONE_DIR="$(mktemp -d /tmp/xone-XXXXXXXX)"
curl -sL -f -o "${XONE_DIR}/src.tar.gz" "https://github.com/dlundqvist/xone/archive/refs/heads/master.tar.gz"
tar -xzf "${XONE_DIR}/src.tar.gz" -C "${XONE_DIR}" --strip-components=1
make -C "${XONE_DIR}" KVERSION="${KERNEL_VERSION}" CC=clang LLVM=1 LD=ld.lld
find "${XONE_DIR}" -maxdepth 1 -name '*.ko' -exec install -Dm644 {} "/usr/lib/modules/${KERNEL_VERSION}/updates/{}" \;

## xone dongle firmware (Microsoft blobs, shipped by the xone installer)
## (the bsdtar binary is a separate package from the libarchive library)
command -v bsdtar >/dev/null 2>&1 || dnf5 -y install bsdtar
"${XONE_DIR}/install/firmware.sh" --skip-disclaimer

rm -rf "${XONE_DIR}"

## xpadneo
XPADNEO_VERSION="v0.10.4"
XPADNEO_DIR="$(mktemp -d /tmp/xpadneo-XXXXXXXX)"
curl -sL -f -o "${XPADNEO_DIR}/src.tar.gz" "https://github.com/atar-axis/xpadneo/archive/refs/tags/${XPADNEO_VERSION}.tar.gz"
tar -xzf "${XPADNEO_DIR}/src.tar.gz" -C "${XPADNEO_DIR}" --strip-components=1
echo "0.10.4" > "${XPADNEO_DIR}/VERSION"
make -C "${XPADNEO_DIR}/hid-xpadneo" KERNEL_SOURCE_DIR="/usr/lib/modules/${KERNEL_VERSION}/build" CC=clang LLVM=1 LD=ld.lld VERSION="0.10.4" modules
make -C "${XPADNEO_DIR}/hid-xpadneo" KERNEL_SOURCE_DIR="/usr/lib/modules/${KERNEL_VERSION}/build" INSTALL_MOD_PATH=/ CC=clang LLVM=1 LD=ld.lld VERSION="0.10.4" modules_install
cp "${XPADNEO_DIR}/hid-xpadneo/etc-modprobe.d/"* /usr/lib/modprobe.d/
cp "${XPADNEO_DIR}/hid-xpadneo/etc-udev-rules.d/"* /usr/lib/udev/rules.d/

rm -rf "${XPADNEO_DIR}"
depmod -a "${KERNEL_VERSION}"
