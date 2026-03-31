#!/bin/bash
# Add AlmaLinux 10 support to scap-security-guide
# This script is intended to run from the unpacked source root during %prep

set -euo pipefail

# 1. Change GRUB EFI dir to /boot/efi/EFI/almalinux everywhere
find ./shared ./linux_os ./tests -type f -exec sed -i 's|EFI/redhat|EFI/almalinux|g' {} \;

# 2. Use ensure_almalinux_gpgkey_installed where applicable in controls
find ./controls -maxdepth 1 -type f -exec sed -i 's|ensure_redhat_gpgkey_installed|ensure_almalinux_gpgkey_installed|g' {} \;

# 3. Add ALMALINUX10 product to build scripts instead of ALMALINUX9
sed -i \
    -e 's/ALMALINUX9/ALMALINUX10/g' \
    -e 's/AlmaLinux OS 9/AlmaLinux OS 10/g' \
    -e 's/almalinux9/almalinux10/g' \
    CMakeLists.txt build_product

# 4. Add AlmaLinux support to linux_os, tests, and shared
find ./linux_os -type d -name ensure_redhat_gpgkey_installed -prune -o -type f -exec sed -i \
    -e '/prodtype:/s/rhel10/rhel10,almalinux10/g' \
    -e '/# platform =/{ /multi_platform_almalinux/! s/multi_platform_rhel/multi_platform_rhel,multi_platform_almalinux/g }' \
    -e '/# platform =/s/Red Hat Enterprise Linux 10/Red Hat Enterprise Linux 10,AlmaLinux OS 10/g' {} \;

find ./tests -type f -exec sed -i \
    -e '/prodtype:/s/rhel10/rhel10,almalinux10/g' \
    -e '/# platform =/{ /multi_platform_almalinux/! s/multi_platform_rhel/multi_platform_rhel,multi_platform_almalinux/g }' \
    -e '/# platform =/s/Red Hat Enterprise Linux 10/Red Hat Enterprise Linux 10,AlmaLinux OS 10/g' {} \;

find ./shared -type f -exec sed -i \
    -e '/prodtype:/s/rhel10/rhel10,almalinux10/g' \
    -e '/# platform =/{ /multi_platform_almalinux/! s/multi_platform_rhel/multi_platform_rhel,multi_platform_almalinux/g }' \
    -e '/# platform =/s/Red Hat Enterprise Linux 10/Red Hat Enterprise Linux 10,AlmaLinux OS 10/g' \
    -e 's|<platform>Red Hat Enterprise Linux 10</platform>|<platform>Red Hat Enterprise Linux 10</platform>\n<platform>AlmaLinux OS 10</platform>|g' \
    -e 's|<platform>multi_platform_rhel</platform>|<platform>multi_platform_rhel</platform>\n<platform>multi_platform_almalinux</platform>|g' {} \;

# 5. Improve Ansible support in conditionals
find ./linux_os -type d -name ensure_redhat_gpgkey_installed -prune -o -type f -exec sed -i \
    -e '/if product in/ s/"rhel10"/"rhel10", "almalinux10"/g' {} \;

# 6. Add AlmaLinux 10 constants
sed -i \
    -e 's/ALMALINUX9/ALMALINUX10/g' \
    -e 's/AlmaLinux OS 9/AlmaLinux OS 10/g' \
    -e 's/almalinux9/almalinux10/g' \
    ssg/constants.py

# 7. Add AlmaLinux 10 product (copy from rhel10 and rebrand)
rm -fr products/almalinux10
cp -r products/rhel10 products/almalinux10

if [ -d products/almalinux10/kickstart ]; then
    for cfg in $(find products/almalinux10/kickstart/ -type f); do
        mv "$cfg" "$(echo "$cfg" | sed 's/rhel10/almalinux10/g')"
    done
    sed -i 's/Red Hat Enterprise Linux 10.*/AlmaLinux OS 10/g' products/almalinux10/kickstart/*
fi

if [ -d products/almalinux10/transforms ]; then
    sed -i \
        -e 's/Red Hat Enterprise Linux/AlmaLinux OS/g' \
        -e 's/RHEL */AL/g' \
        -e 's/rhel/almalinux/g' \
        -e 's/red_hat_linux/almalinuxos_linux/g' \
        products/almalinux10/transforms/*
fi

if [ -d products/almalinux10/overlays ]; then
    sed -i \
        -e 's/Red Hat Enterprise Linux/AlmaLinux OS/g' \
        -e 's/Red Hat Network or a Satellite Server/Foreman/g' \
        -e 's/Red Hat/AlmaLinux/g' \
        -e 's/RHEL10/AlmaLinux OS 10/g' \
        -e 's/RHEL/AlmaLinux OS/g' \
        products/almalinux10/overlays/*
fi

if [ -d products/almalinux10/controls ]; then
    for ctl in $(find products/almalinux10/controls/ -type f -name '*rhel10*'); do
        mv "$ctl" "$(echo "$ctl" | sed 's/rhel10/almalinux10/g')"
    done
    find products/almalinux10/controls -type f -exec sed -i \
        -e 's/Red Hat Enterprise Linux/AlmaLinux OS/g' \
        -e 's/RHEL10/ALMALINUX10/g' \
        -e 's/RHEL-10/ALMALINUX-10/g' \
        -e 's/RHEL/AlmaLinux/g' \
        -e 's/Red Hat/AlmaLinux/g' \
        -e '/^id:/s/rhel10/almalinux10/g' \
        -e '/^product:/s/rhel10/almalinux10/g' \
        -e 's/ensure_redhat_gpgkey_installed/ensure_almalinux_gpgkey_installed/g' {} \;
fi

sed -i \
    -e 's/rhel10/almalinux10/' \
    -e 's/Red Hat Enterprise Linux/AlmaLinux OS/g' \
    -e 's/RHEL-10/ALMALINUX-10/g' \
    -e 's#https://access.redhat.com/security/team/key#https://almalinux.org/security/#' \
    -e 's/^pkg_release:.*/pkg_release: "668fe8ef"/g' \
    -e 's/^pkg_version:.*/pkg_version: "c2a1e572"/g' \
    -e '/^aux_pkg_release:/d' \
    -e '/^aux_pkg_version:/d' \
    -e 's/release_key_fingerprint:.*/release_key_fingerprint: "EE6DB7B98F5BF5EDD9DA0DE5DEE5C11CC2A1E572"/g' \
    -e '/^release_key_fingerprint:/a oval_feed_url: "https://security.almalinux.org/oval/org.almalinux.alsa-10.xml.bz2"' \
    -e '/^auxiliary_key_fingerprint:/d' \
    -e '/^pqc_key_fingerprint:/d' \
    -e '/^pqc_pkg_release:/d' \
    -e '/^pqc_pkg_version:/d' \
    -e 's/redhat:enterprise_linux/almalinux:almalinux/g' \
    -e 's/red_hat_linux/almalinuxos_linux/g' \
    -e '/^centos_/d' \
    products/almalinux10/product.yml

sed -i 's/rhel/almalinux/g' products/almalinux10/CMakeLists.txt

sed -i -z \
    -e 's/Red Hat Enterprise Linux/AlmaLinux OS/g' \
    -e 's/red_hat_linux/almalinuxos_linux/g' \
    -e 's/Red Hat Enterprise\n    Linux/\n    AlmaLinux OS/g' \
    -e 's/released ....-..-../released 2025-09-30/g' \
    -e 's/RHEL/AlmaLinux OS/g' \
    products/almalinux10/profiles/*

sed -i \
    -e 's/ensure_redhat_gpgkey_installed/ensure_almalinux_gpgkey_installed/g' \
    -e 's/rhel10:/almalinux10:/g' \
    -e "s/'\!ensure_almalinux_gpgkey_installed'/ensure_almalinux_gpgkey_installed/g" \
    products/almalinux10/profiles/*
