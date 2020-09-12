#!/usr/bin/env bash
set -eux -o pipefail

chromium_version=85.0.4183.83
chrome_modern_apk_target=chrome_modern_public_apk
trichrome_chrome_bundle_target=trichrome_chrome_bundle
webview_target=system_webview_apk

# Create symbol links to gn, depot-tools
pushd src
pushd buildtools/linux64
ln -s /usr/bin/gn
popd

pushd third_party
ln -s ../../depot_tools
popd
popd

## Set compiler flags
export AR=${AR:=llvm-ar}
export NM=${NM:=llvm-nm}
export CC=${CC:=clang}
export CXX=${CXX:=clang++}

# Fix repos
ui_automator_commit=$(grep 'ub-uiautomator\.git' src/DEPS | cut -d\' -f10)
mkdir src/third_party/ub-uiautomator/lib
pushd src/third_party/ub-uiautomator/lib
git init
git remote add origin https://chromium.googlesource.com/chromium/third_party/ub-uiautomator.git
git fetch --depth 1 --no-tags origin "${ui_automator_commit}"
git reset --hard FETCH_HEAD
popd

robolectric_commit=$(grep 'robolectric\.git' src/DEPS | cut -d\' -f10)
mkdir -p src/third_party/robolectric/robolectric
pushd src/third_party/robolectric/robolectric
git init
git remote add origin https://chromium.googlesource.com/external/robolectric.git
git fetch --depth 1 --no-tags origin "${robolectric_commit}"
git reset --hard FETCH_HEAD
popd

netty4_commit=$(grep 'netty4\.git' src/DEPS | cut -d\' -f10)
mkdir -p src/third_party/netty4/src
pushd src/third_party/netty4/src
git init
git remote add origin https://chromium.googlesource.com/external/netty4.git
git fetch --depth 1 --no-tags origin "${netty4_commit}"
git reset --hard FETCH_HEAD
popd

# Need different GN flags than a release build
pushd src
output_folder=out/Debug_apk
#output_folder=out/Debug_apk_x86
mkdir -p ${output_folder}
cat ../android_flags.debug.gn ../android_flags.gn > ${output_folder}/args.gn
printf '\ntarget_cpu="x86"\n' >> ${output_folder}/args.gn
popd

# Run gn first
pushd src
gn gen ${output_folder} --fail-on-unused-args
popd

# Compile apk
pushd src
ninja -C ${output_folder} ${chrome_modern_apk_target}
popd

###
# Develop folder
pushd src
output_folder=out/Debug
mkdir -p ${output_folder}
cat ../android_flags.debug.gn ../android_flags.gn > ${output_folder}/args.gn
printf '\ntarget_cpu="x86"\n' >> ${output_folder}/args.gn

# Run gn first
gn gen ${output_folder} --fail-on-unused-args

# Generate gradle files
# patch generate_gradle.py to use system ninja instead of depot_tools
pushd ..
patch -p1 --ignore-whitespace -i patches/Other/generate_gradle.patch --no-backup-if-mismatch
popd
# patch -p1 --ignore-whitespace -i ../patches/src-fix/fix-unkown-warning-clang-9.patch --no-backup-if-mismatch
python build/android/gradle/generate_gradle.py --target //chrome/android:${chrome_modern_apk_target} --output-directory ${output_folder}
popd
