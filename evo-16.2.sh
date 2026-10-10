#!/usr/bin/env bash

set -Eeuo pipefail

echo "=============================================="
echo "   RMX1851 Evolution X 16.2 Crave Builder"
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

CLANG_REPO="https://github.com/kdrag0n/proton-clang.git"

DOLBY_REPO="https://github.com/tranQuila-Project/vendor_lunaris_dolby.git"

DEVICE_PATH="device/realme/RMX1851"
KERNEL_PATH="kernel/realme/sdm710"
VENDOR_PATH="vendor/realme/RMX1851"
CLANG_PATH="prebuilts/clang/host/linux-x86/clang-proton"
DOLBY_PATH="vendor/lunaris/dolby"

#############################################
# ERROR HANDLER
#############################################

trap 'rc=$?; echo "ERROR: Script failed at line $LINENO (exit code $rc)."; exit "$rc"' ERR

#############################################
# REPOSITORY CLONE HELPER
#############################################

clone_repo() {
    local url="$1"
    local path="$2"
    local branch="${3:-}"

    if [[ -d "$path/.git" ]]; then
        echo ">>> Repository already exists: $path"
        return 0
    fi

    if [[ -e "$path" ]]; then
        echo "ERROR: $path exists but is not a Git repository."
        return 1
    fi

    mkdir -p "$(dirname "$path")"

    echo ">>> Cloning $path"

    if [[ -n "$branch" ]]; then
        git clone --depth=1 --branch "$branch" "$url" "$path"
    else
        git clone --depth=1 "$url" "$path"
    fi
}

#############################################
# CHERRY-PICK HELPER
#############################################

cherry_pick_if_needed() {
    local commit="$1"

    echo ">>> Checking patch: $commit"

    if git merge-base --is-ancestor "$commit" HEAD 2>/dev/null; then
        echo ">>> Patch already exists in history; skipping."
        return 0
    fi

    if git cherry-pick "$commit"; then
        echo ">>> Patch applied successfully."
        return 0
    fi

    # Only skip a failed cherry-pick if Git confirms it is empty.
    if git status --porcelain | grep -q .; then
        echo "ERROR: Cherry-pick failed or has conflicts: $commit"
        git cherry-pick --abort || true
        return 1
    fi

    if git rev-parse -q --verify CHERRY_PICK_HEAD >/dev/null 2>&1; then
        echo "ERROR: Cherry-pick is still in progress: $commit"
        git cherry-pick --abort || true
        return 1
    fi

    echo "ERROR: Cherry-pick failed for an unexpected reason: $commit"
    return 1
}

#############################################
# SET OR ADD GIT REMOTE
#############################################

set_git_remote() {
    local remote="$1"
    local url="$2"

    if git remote get-url "$remote" >/dev/null 2>&1; then
        git remote set-url "$remote" "$url"
    else
        git remote add "$remote" "$url"
    fi
}

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
echo "=============================================="
echo " Cloning RMX1851 device tree"
echo "=============================================="

clone_repo "$DEVICE_REPO" "$DEVICE_PATH" "$DEVICE_BRANCH"

#############################################
# REMOVE OLD VENDORSETUP CLONE SCRIPT
#############################################

echo
echo "==> Preventing duplicate repository clones..."

if [[ -f "$DEVICE_PATH/vendorsetup.sh" ]]; then
    echo ">>> Removing device-tree vendorsetup.sh"
    rm -f "$DEVICE_PATH/vendorsetup.sh"
fi

#############################################
# KERNEL, VENDOR AND PROTON CLANG
#############################################

echo
echo "=============================================="
echo " Setting up kernel, vendor and Clang"
echo "=============================================="

clone_repo "$KERNEL_REPO" "$KERNEL_PATH" "$KERNEL_BRANCH"
clone_repo "$VENDOR_REPO" "$VENDOR_PATH" "$VENDOR_BRANCH"
clone_repo "$CLANG_REPO" "$CLANG_PATH"

#############################################
# CONNECTIVITY CHERRY-PICKS
#############################################

echo
echo "=============================================="
echo " Applying Connectivity cherry-picks"
echo "=============================================="

pushd packages/modules/Connectivity >/dev/null

set_git_remote bava \
    https://github.com/kaderbava/android_packages_modules_Connectivity.git

git fetch --depth=50 bava

cherry_pick_if_needed c8ae1a501bc946ee9b3fa21e30958905db48187a
cherry_pick_if_needed 408b8a8bcda2e9f933bc4e6dd030f7db48d2a7a0
cherry_pick_if_needed f22ea60ed3338424f9d3ca757f3de7b4b232984e
cherry_pick_if_needed 14e4131a986af724f7471b2058248ae6a5c2fb57
cherry_pick_if_needed b201adf4edccd8e942008b6c016dfdab4bf027b2
cherry_pick_if_needed 9964b13f83802fce9ec5da611ed76453c1d4f629
cherry_pick_if_needed d130aa5afc5e3c4da2c53101adfc615ec90463d8
cherry_pick_if_needed 109d4b3b4f7a678db8263d39542256b2d14f1330
cherry_pick_if_needed d13655358375cb2111aebe26785293f121f4abf3
cherry_pick_if_needed 924eefb17a009a2720ad075579081ca3b1034417
cherry_pick_if_needed 0fd046db711077d5646f447a8b827ca4cf0ca7b7
cherry_pick_if_needed e4cbeb4468b06432aea73d38977c4ab59bad828c
cherry_pick_if_needed 678cf1623828a21ce37aac1207d112414b36ba7f
cherry_pick_if_needed 8f98c969de321cd347c510f21ed6969c2600340e

popd >/dev/null

#############################################
# HARDWARE LINEAGE COMPAT CHERRY-PICKS
#############################################

echo
echo "=============================================="
echo " Applying hardware/lineage/compat patches"
echo "=============================================="

pushd hardware/lineage/compat >/dev/null

set_git_remote bava \
    https://github.com/kaderbava/android_hardware_lineage_compat.git

git fetch bava

cherry_pick_if_needed 1f07eab3cef1cf0b0e304ee9b4bf36103d812779
cherry_pick_if_needed f37f07775713433868cbd244174a64d3e3bf47f0

popd >/dev/null

#############################################
# DISABLE SENSORS MULTIHAL
#############################################

echo
echo "==> Disabling sensors multihal..."

SENSOR_BP="hardware/interfaces/sensors/2.0/multihal/Android.bp"

if [[ ! -f "$SENSOR_BP" ]]; then
    echo "ERROR: Sensors Android.bp not found: $SENSOR_BP"
    exit 1
fi

if grep -q 'enabled: false,' "$SENSOR_BP"; then
    echo ">>> Sensors MultiHAL already disabled."
else
    sed -i '/name: "android.hardware.sensors@2.0-service.multihal",/a\    enabled: false,' "$SENSOR_BP"
    echo ">>> Sensors MultiHAL disabled."
fi

#############################################
# SEPOLICY DOMAIN FIX
#############################################

echo
echo "==> Applying domain.te compatibility fix..."

DOMAIN_TE="system/sepolicy/private/domain.te"

if [[ ! -f "$DOMAIN_TE" ]]; then
    echo "ERROR: Missing $DOMAIN_TE"
    exit 1
fi

# Preserve the original intended line-744 change.
sed -i '744s/^[[:space:]]*/# /' "$DOMAIN_TE"

#############################################
# DOLBY
#############################################

echo
echo "=============================================="
echo " Setting up Dolby integration"
echo "=============================================="

clone_repo "$DOLBY_REPO" "$DOLBY_PATH"

#############################################
# BUILD SIGNING ENVIRONMENT
#############################################

echo
echo "=============================================="
echo " Creating signed build environment"
echo "=============================================="

curl -fsSL \
    https://raw.githubusercontent.com/Trijal08/crDroid-build-signed-script-auto/main/create-signed-env.sh \
    | /usr/bin/env bash

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

m evolution -j"$(nproc --all)"

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
