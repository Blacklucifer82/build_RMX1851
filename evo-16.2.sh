#!/usr/bin/env bash

set -e

echo "=============================================="
echo "   RMX1851 Evolution X 11.x Crave Builder"
echo "=============================================="

#############################################
# CONFIG
#############################################

ROM_BRANCH="bka"

DEVICE_REPO="https://github.com/Blacklucifer82/device_realme_RMX1851-A16.git"
DEVICE_BRANCH="evo-16"

KERNEL_REPO="https://github.com/Blacklucifer82/android_kernel_realme_sdm710.git"
KERNEL_BRANCH="16-bpf"

VENDOR_REPO="https://github.com/Blacklucifer82/vendor-realme-RMX1851-A16.git"
VENDOR_BRANCH="16"

DEVICE_PATH="device/realme/RMX1851"
KERNEL_PATH="kernel/realme/sdm710"
VENDOR_PATH="vendor/realme/RMX1851"

CLANG_PATH="prebuilts/clang/host/linux-x86/clang-proton"

KEYS_REPO="https://github.com/Evolution-X/vendor_evolution-priv_keys-template"
KEYS_PATH="vendor/evolution-priv/keys"

#############################################
# INITIALIZE EVOLUTION X
#############################################

echo
echo "==> Initializing Evolution X..."

rm -rf .repo/local_manifests

repo init \
    -u https://github.com/Evolution-X/manifest.git \
    -b "$ROM_BRANCH" \
    --depth=1 \
    --git-lfs

#############################################
# SYNC EVOLUTION X
#############################################

echo
echo "==> Syncing Evolution X source..."

/opt/crave/resync.sh

#############################################
# DEVICE TREE
#############################################

echo
echo "==> Cloning RMX1851 device tree..."

rm -rf "$DEVICE_PATH"

mkdir -p "$(dirname "$DEVICE_PATH")"

git clone \
    --depth=1 \
    --branch "$DEVICE_BRANCH" \
    "$DEVICE_REPO" \
    "$DEVICE_PATH"

#############################################
# KERNEL
#############################################

echo
echo "==> Cloning RMX1851 kernel..."

rm -rf "$KERNEL_PATH"

mkdir -p "$(dirname "$KERNEL_PATH")"

git clone \
    --depth=1 \
    --branch "$KERNEL_BRANCH" \
    "$KERNEL_REPO" \
    "$KERNEL_PATH"

#############################################
# VENDOR
#############################################

echo
echo "==> Cloning RMX1851 vendor..."

rm -rf "$VENDOR_PATH"

mkdir -p "$(dirname "$VENDOR_PATH")"

git clone \
    --depth=1 \
    --branch "$VENDOR_BRANCH" \
    "$VENDOR_REPO" \
    "$VENDOR_PATH"

#############################################
# CLANG
#############################################

echo
echo "==> Cloning Proton Clang..."

rm -rf "$CLANG_PATH"

mkdir -p "$(dirname "$CLANG_PATH")"

git clone \
    --depth=1 \
    https://github.com/kdrag0n/proton-clang.git \
    "$CLANG_PATH"

#############################################
# CONNECTIVITY CHERRY-PICKS
#############################################

echo
echo "=============================================="
echo " Applying Connectivity cherry-picks"
echo "=============================================="

cd packages/modules/Connectivity

git remote add bava \
    https://github.com/kaderbava/android_packages_modules_Connectivity.git

git fetch --depth 50 bava

git cherry-pick c8ae1a501bc946ee9b3fa21e30958905db48187a
git cherry-pick 408b8a8bcda2e9f933bc4e6dd030f7db48d2a7a0
git cherry-pick f22ea60ed3338424f9d3ca757f3de7b4b232984e
git cherry-pick 14e4131a986af724f7471b2058248ae6a5c2fb57
git cherry-pick b201adf4edccd8e942008b6c016dfdab4bf027b2
git cherry-pick 9964b13f83802fce9ec5da611ed76453c1d4f629
git cherry-pick d130aa5afc5e3c4da2c53101adfc615ec90463d8
git cherry-pick 109d4b3b4f7a678db8263d39542256b2d14f1330
git cherry-pick d13655358375cb2111aebe26785293f121f4abf3
git cherry-pick 924eefb17a009a2720ad075579081ca3b1034417
git cherry-pick 0fd046db711077d5646f447a8b827ca4cf0ca7b7
git cherry-pick e4cbeb4468b06432aea73d38977c4ab59bad828c
git cherry-pick 678cf1623828a21ce37aac1207d112414b36ba7f
git cherry-pick 8f98c969de321cd347c510f21ed6969c2600340e

cd - >/dev/null

#############################################
# HARDWARE LINEAGE COMPAT CHERRY-PICKS
#############################################

echo
echo "=============================================="
echo " Applying hardware/lineage/compat patches"
echo "=============================================="

cd hardware/lineage/compat

git remote add bava \
    https://github.com/kaderbava/android_hardware_lineage_compat.git

git fetch bava

git cherry-pick 1f07eab3cef1cf0b0e304ee9b4bf36103d812779
git cherry-pick f37f07775713433868cbd244174a64d3e3bf47f0

cd - >/dev/null

#############################################
# DISABLE SENSORS MULTIHAL
#############################################

echo
echo "==> Disabling sensors multihal..."

SENSOR_BP="hardware/interfaces/sensors/2.0/multihal/Android.bp"

if grep -q 'enabled: false,' "$SENSOR_BP"; then
    echo "Sensors multihal already disabled."
else
    sed -i '/^[[:space:]]*enabled:/c\    enabled: false,' "$SENSOR_BP"
fi

#############################################
# SEPOLICY DOMAIN FIX
#############################################

echo
echo "==> Applying domain.te compatibility fix..."

DOMAIN_TE="system/sepolicy/private/domain.te"

sed -i '744s/^[[:space:]]*/# /' "$DOMAIN_TE"

#############################################
# EVOLUTION X PRIVATE SIGNING KEYS
#############################################

echo
echo "=============================================="
echo " Setting up Evolution X signing keys"
echo "=============================================="

rm -rf "$KEYS_PATH"

git clone \
    --depth=1 \
    "$KEYS_REPO" \
    "$KEYS_PATH"

echo
echo "==> Generating Evolution X signing keys..."

cd "$KEYS_PATH"

chmod +x keys.sh

./keys.sh || {
    echo "WARNING: keys.sh returned non-zero status; continuing with generated keys."
}

cd - >/dev/null

#############################################
# BUILD ENVIRONMENT
#############################################

echo
echo "=============================================="
echo " Preparing Android build environment"
echo "=============================================="

source build/envsetup.sh

export BUILD_USERNAME=SOURABH
export BUILD_HOSTNAME=crave

#############################################
# LUNCH
#############################################

echo
echo "==> Selecting RMX1851..."

lunch lineage_RMX1851-bp4a-user

#############################################
# BUILD
#############################################

echo
echo "=============================================="
echo " Starting RMX1851 Evolution X build"
echo "=============================================="

m evolution -j$(nproc --all)

#############################################
# OUTPUT
#############################################

echo
echo "=============================================="
echo " BUILD FINISHED"
echo "=============================================="

echo "Output files:"

find out/target/product/RMX1851 \
    -maxdepth 1 \
    -type f \
    \( -name "*.zip" -o -name "*.img" \) \
    -printf '%p\n'

echo
echo "=============================================="
echo " Done"
echo "=============================================="
