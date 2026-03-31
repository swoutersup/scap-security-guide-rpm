#!/bin/bash
# Add AlmaLinux 9 support to scap-security-guide
# This script is intended to run from the unpacked source root during %prep

set -euo pipefail

# 1. Change GRUB EFI dir to /boot/efi/EFI/almalinux everywhere
find ./shared ./linux_os ./tests -type f -exec sed -i 's|EFI/redhat|EFI/almalinux|g' {} \;

# 2. Use ensure_almalinux_gpgkey_installed where applicable in controls
find ./controls -maxdepth 1 -type f -exec sed -i 's|ensure_redhat_gpgkey_installed|ensure_almalinux_gpgkey_installed|g' {} \;

# 3. Add AlmaLinux support to linux_os, tests, and shared
find ./linux_os -type d -name ensure_redhat_gpgkey_installed -prune -o -type f -exec sed -i \
    -e '/prodtype:/s/rhel9/rhel9,almalinux9/g' \
    -e '/# platform =/{ /multi_platform_almalinux/! s/multi_platform_rhel/multi_platform_rhel,multi_platform_almalinux/g }' \
    -e '/# platform =/s/Red Hat Enterprise Linux 9/Red Hat Enterprise Linux 9,AlmaLinux OS 9/g' {} \;

find ./tests -type f -exec sed -i \
    -e '/prodtype:/s/rhel9/rhel9,almalinux9/g' \
    -e '/# platform =/{ /multi_platform_almalinux/! s/multi_platform_rhel/multi_platform_rhel,multi_platform_almalinux/g }' \
    -e '/# platform =/s/Red Hat Enterprise Linux 9/Red Hat Enterprise Linux 9,AlmaLinux OS 9/g' {} \;

find ./shared -type f -exec sed -i \
    -e '/prodtype:/s/rhel9/rhel9,almalinux9/g' \
    -e '/# platform =/{ /multi_platform_almalinux/! s/multi_platform_rhel/multi_platform_rhel,multi_platform_almalinux/g }' \
    -e '/# platform =/s/Red Hat Enterprise Linux 9/Red Hat Enterprise Linux 9,AlmaLinux OS 9/g' \
    -e 's|<platform>Red Hat Enterprise Linux 9</platform>|<platform>Red Hat Enterprise Linux 9</platform>\n<platform>AlmaLinux OS 9</platform>|g' \
    -e 's|<platform>multi_platform_rhel</platform>|<platform>multi_platform_rhel</platform>\n<platform>multi_platform_almalinux</platform>|g' {} \;

# 4. Improve Ansible support in conditionals
find ./linux_os -type d -name ensure_redhat_gpgkey_installed -prune -o -type f -exec sed -i \
    -e '/if product in/ s/"rhel9"/"rhel9", "almalinux9"/g' {} \;

# 5. Add disa references symlinks for AlmaLinux
for xml in $(find shared/references/ -type f -name 'disa-stig-rhel*.xml'); do
    target="$(echo "$xml" | sed 's/rhel/almalinux/g')"
    if [ ! -e "$target" ]; then
        ln -s "$(basename "$xml")" "$target"
    fi
done

# 6. Add AlmaLinux 9 product (copy from rhel9 and rebrand)
rm -fr products/almalinux9
cp -r products/rhel9 products/almalinux9

if [ -d products/almalinux9/kickstart ]; then
    for cfg in $(find products/almalinux9/kickstart/ -type f); do
        mv "$cfg" "$(echo "$cfg" | sed 's/rhel9/almalinux9/g')"
    done
    sed -i 's/Red Hat Enterprise Linux 9.*/AlmaLinux OS 9/g' products/almalinux9/kickstart/*
fi

if [ -d products/almalinux9/transforms ]; then
    sed -i \
        -e 's/Red Hat Enterprise Linux/AlmaLinux OS/g' \
        -e 's/RHEL */AL/g' \
        -e 's/rhel/almalinux/g' \
        -e 's/red_hat_linux/almalinuxos_linux/g' \
        products/almalinux9/transforms/*
fi

if [ -d products/almalinux9/overlays ]; then
    sed -i \
        -e 's/Red Hat Enterprise Linux/AlmaLinux OS/g' \
        -e 's/Red Hat Network or a Satellite Server/Foreman/g' \
        -e 's/Red Hat/AlmaLinux/g' \
        -e 's/RHEL9/AlmaLinux OS 9/g' \
        -e 's/RHEL/AlmaLinux OS/g' \
        products/almalinux9/overlays/*
fi

if [ -d products/almalinux9/controls ]; then
    for ctl in $(find products/almalinux9/controls/ -type f -name '*rhel9*'); do
        mv "$ctl" "$(echo "$ctl" | sed 's/rhel9/almalinux9/g')"
    done
    find products/almalinux9/controls -type f -exec sed -i \
        -e 's/Red Hat Enterprise Linux/AlmaLinux OS/g' \
        -e 's/RHEL9/ALMALINUX9/g' \
        -e 's/RHEL-9/ALMALINUX-9/g' \
        -e '/^id:/s/rhel9/almalinux9/g' \
        -e '/^product:/s/rhel9/almalinux9/g' \
        -e 's/ensure_redhat_gpgkey_installed/ensure_almalinux_gpgkey_installed/g' {} \;
fi

sed -i \
    -e 's/rhel9/almalinux9/' \
    -e 's/Red Hat Enterprise Linux/AlmaLinux OS/g' \
    -e 's/RHEL-9/ALMALINUX-9/g' \
    -e 's#https://access.redhat.com/security/team/key#https://almalinux.org/security/#' \
    -e 's/^pkg_release:.*/pkg_release: "61e69f29"/g' \
    -e 's/^pkg_version:.*/pkg_version: "b86b3716"/g' \
    -e '/^aux_pkg_release:/d' \
    -e '/^aux_pkg_version:/d' \
    -e 's/release_key_fingerprint:.*/release_key_fingerprint: "BF18AC2876178908D6E71267D36CB86CB86B3716"/g' \
    -e '/^release_key_fingerprint:/a oval_feed_url: "https://security.almalinux.org/oval/org.almalinux.alsa-9.xml.bz2"' \
    -e '/^auxiliary_key_fingerprint:/d' \
    -e '/^pqc_key_fingerprint:/d' \
    -e '/^pqc_pkg_release:/d' \
    -e '/^pqc_pkg_version:/d' \
    -e 's/redhat:enterprise_linux/almalinux:almalinux/g' \
    -e 's/red_hat_linux/almalinuxos_linux/g' \
    -e '/^centos_/d' \
    products/almalinux9/product.yml

sed -i 's/rhel/almalinux/g' products/almalinux9/CMakeLists.txt

sed -i -z \
    -e 's/Red Hat Enterprise Linux/AlmaLinux OS/g' \
    -e 's/red_hat_linux/almalinuxos_linux/g' \
    -e 's/Red Hat Enterprise\n    Linux/\n    AlmaLinux OS/g' \
    -e 's/released ....-..-../released 2024-06-24/g' \
    -e 's/RHEL/AlmaLinux OS/g' \
    products/almalinux9/profiles/*

sed -i \
    -e 's/ensure_redhat_gpgkey_installed/ensure_almalinux_gpgkey_installed/g' \
    -e 's/rhel9:/almalinux9:/g' \
    -e "s/'\!ensure_almalinux_gpgkey_installed'/ensure_almalinux_gpgkey_installed/g" \
    -e '/"!ensure_almalinux_gpgkey_installed"/d' \
    products/almalinux9/profiles/*
