#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$SCRIPT_DIR"

DEFAULT_ANDROID_SDK="D:/Program Files/Unity 2021.3.43f1/Editor/Data/PlaybackEngines/AndroidPlayer/SDK"
DEFAULT_ANDROID_NDK="G:/Android/android-ndk-r14b-windows-x86_64/android-ndk-r14b"
DEFAULT_JAVA_HOME="D:/Program Files/Unity 2021.3.43f1/Editor/Data/PlaybackEngines/AndroidPlayer/OpenJDK"
DEFAULT_VSDEVCMD_BAT="C:/Program Files/Microsoft Visual Studio/2022/Community/Common7/Tools/VsDevCmd.bat"

ANDROID_SDK=${ANDROID_SDK:-$DEFAULT_ANDROID_SDK}
ANDROID_NDK=${ANDROID_NDK:-$DEFAULT_ANDROID_NDK}
JAVA_HOME=${JAVA_HOME:-$DEFAULT_JAVA_HOME}
VSDEVCMD_BAT=${VSDEVCMD_BAT:-$DEFAULT_VSDEVCMD_BAT}
ANDROID_BUILD_TOOLS_VERSION=${ANDROID_BUILD_TOOLS_VERSION:-32.0.0}
APK_TARGET_ID=${APK_TARGET_ID:-android-30}
CMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE:-RelWithDebInfo}

CMAKE_EXE="$ANDROID_SDK/cmake/3.22.1/bin/cmake.exe"
NINJA_EXE="$ANDROID_SDK/cmake/3.22.1/bin/ninja.exe"
JAVA_EXE="$JAVA_HOME/bin/java.exe"
JAVAC_EXE="$JAVA_HOME/bin/javac.exe"
ANDROID_JAR="$ANDROID_SDK/platforms/$APK_TARGET_ID/android.jar"
BUILD_TOOLS="$ANDROID_SDK/build-tools/$ANDROID_BUILD_TOOLS_VERSION"

if [ ! -f "$JAVA_EXE" ] && [ -f "$DEFAULT_JAVA_HOME/bin/java.exe" ]; then
  JAVA_HOME=$DEFAULT_JAVA_HOME
  JAVA_EXE="$JAVA_HOME/bin/java.exe"
  JAVAC_EXE="$JAVA_HOME/bin/javac.exe"
fi

if [ ! -f "$CMAKE_EXE" ] && [ -f "$DEFAULT_ANDROID_SDK/cmake/3.22.1/bin/cmake.exe" ]; then
  ANDROID_SDK=$DEFAULT_ANDROID_SDK
  CMAKE_EXE="$ANDROID_SDK/cmake/3.22.1/bin/cmake.exe"
  NINJA_EXE="$ANDROID_SDK/cmake/3.22.1/bin/ninja.exe"
  ANDROID_JAR="$ANDROID_SDK/platforms/$APK_TARGET_ID/android.jar"
  BUILD_TOOLS="$ANDROID_SDK/build-tools/$ANDROID_BUILD_TOOLS_VERSION"
fi

if [ ! -d "$ANDROID_NDK" ] && [ -d "$DEFAULT_ANDROID_NDK" ]; then
  ANDROID_NDK=$DEFAULT_ANDROID_NDK
fi

if [ ! -f "$VSDEVCMD_BAT" ] && [ -f "$DEFAULT_VSDEVCMD_BAT" ]; then
  VSDEVCMD_BAT=$DEFAULT_VSDEVCMD_BAT
fi

require_file() {
  if [ ! -f "$1" ]; then
    echo "$2 not found: $1" >&2
    exit 1
  fi
}

require_dir() {
  if [ ! -d "$1" ]; then
    echo "$2 not found: $1" >&2
    exit 1
  fi
}

make_host_cxx_wrapper() {
  build_dir=$1
  build_dir_abs=$(cd "$build_dir" 2>/dev/null && pwd -W || { mkdir -p "$build_dir" && cd "$build_dir" && pwd -W; })
  wrapper="$build_dir_abs/host-cxx.cmd"
  mkdir -p "$build_dir"
  cat > "$wrapper" <<EOF
@echo off
setlocal

set "SRC=%~1"
set "OUT=%~3"

if not "%~2"=="-o" (
  echo Expected arguments: source.cpp -o output.exe
  exit /b 2
)

call "$VSDEVCMD_BAT" -arch=x64 -host_arch=x64 >nul
if errorlevel 1 exit /b %errorlevel%

cl /nologo /EHsc /std:c++14 "%SRC%" /Fe"%OUT%" /Fo"%OUT%.obj"
exit /b %errorlevel%
EOF
  printf '%s\n' "$wrapper"
}

sign_and_verify_apk() {
  cmd_dir=$1
  apk_path=$2

  (cd "$cmd_dir" && "$BUILD_TOOLS/apksigner.bat" sign \
    --ks debug.keystore \
    --ks-pass pass:android \
    --key-pass pass:android \
    --ks-key-alias rdocandroidkey \
    RenderDocCmd.apk)

  cp -f "$cmd_dir/RenderDocCmd.apk" "$apk_path"
  "$BUILD_TOOLS/apksigner.bat" verify --verbose "$apk_path"
}

build_one_abi() {
  abi=$1
  suffix=$2
  build_dir=$3

  wrapper=$(make_host_cxx_wrapper "$build_dir")

  export JAVA_HOME
  export ANDROID_SDK
  export ANDROID_SDK_ROOT="$ANDROID_SDK"
  export ANDROID_HOME="$ANDROID_SDK"
  export ANDROID_NDK
  export ANDROID_NDK_ROOT="$ANDROID_NDK"
  export PATH="$JAVA_HOME/bin:$ANDROID_SDK/cmake/3.22.1/bin:$PATH"

  "$CMAKE_EXE" -S . -B "$build_dir" -G Ninja \
    -DBUILD_ANDROID=On \
    -DANDROID_ABI="$abi" \
    -DCMAKE_BUILD_TYPE="$CMAKE_BUILD_TYPE" \
    -DANDROID_BUILD_TOOLS_VERSION="$ANDROID_BUILD_TOOLS_VERSION" \
    -DAPK_TARGET_ID="$APK_TARGET_ID" \
    -DHOST_NATIVE_CPP_COMPILER="$wrapper"

  "$NINJA_EXE" -C "$build_dir" \
    lib/libVkLayer_GLES_RenderDoc.so \
    lib/librenderdoccmd.so \
    renderdoccmd/debug.keystore

  cmd_dir="$build_dir/renderdoccmd"
  abi_lib_dir="$cmd_dir/libs/lib/$abi"
  mkdir -p "$abi_lib_dir" "$cmd_dir/obj" "$cmd_dir/bin" "$build_dir/bin"
  cp -f "$build_dir/lib/libVkLayer_GLES_RenderDoc.so" "$abi_lib_dir/libVkLayer_GLES_RenderDoc.so"
  cp -f "$build_dir/lib/librenderdoccmd.so" "$abi_lib_dir/librenderdoccmd.so"
  if [ ! -f "$abi_lib_dir/wrap.sh" ]; then
    cp -f "renderdoccmd/android/wrap.sh" "$abi_lib_dir/wrap.sh"
  fi

  (cd "$cmd_dir" && "$BUILD_TOOLS/aapt.exe" package -f -m \
    -S res \
    -J src \
    -M AndroidManifest.xml \
    -I "$ANDROID_JAR")

  java_sources=$(cd "$cmd_dir" && find src/org/renderdoc/renderdoccmd -name '*.java' -print)
  if [ -z "$java_sources" ]; then
    echo "No Java sources found under $cmd_dir/src/org/renderdoc/renderdoccmd" >&2
    exit 1
  fi

  # shellcheck disable=SC2086
  (cd "$cmd_dir" && "$JAVAC_EXE" \
    -d ./obj \
    -source 1.7 \
    -target 1.7 \
    -classpath "$ANDROID_JAR;obj" \
    -sourcepath src \
    $java_sources)

  (cd "$cmd_dir" && "$JAVA_EXE" -Xmx1024M -Xss1m \
    -cp "$BUILD_TOOLS/lib/d8.jar" \
    com.android.tools.r8.D8 \
    --output ./bin/ \
    "./obj/org/renderdoc/renderdoccmd/$suffix/Loader.class")

  version_name=$(git rev-parse HEAD)
  (cd "$cmd_dir" && "$BUILD_TOOLS/aapt.exe" package -f \
    -M AndroidManifest.xml \
    --version-code 145 \
    --version-name "$version_name" \
    -S res \
    -I "$ANDROID_JAR" \
    -F RenderDocCmd-unaligned.apk \
    bin libs)

  (cd "$cmd_dir" && "$BUILD_TOOLS/zipalign.exe" -f 4 RenderDocCmd-unaligned.apk RenderDocCmd.apk)

  apk_path="$build_dir/bin/org.renderdoc.renderdoccmd.$suffix.apk"
  sign_and_verify_apk "$cmd_dir" "$apk_path"
  final_dir="x64/plugins/android"
  final_apk="$final_dir/org.renderdoc.renderdoccmd.$suffix.apk"
  mkdir -p "$final_dir"
  cp -f "$apk_path" "$final_apk"
  echo "APK output: $apk_path"
  echo "Copied APK to: $final_apk"
}

require_dir "$ANDROID_SDK" "ANDROID_SDK"
require_dir "$ANDROID_NDK" "ANDROID_NDK"
require_dir "$JAVA_HOME" "JAVA_HOME"
require_file "$VSDEVCMD_BAT" "VSDEVCMD_BAT"
require_file "$CMAKE_EXE" "cmake.exe"
require_file "$NINJA_EXE" "ninja.exe"
require_file "$JAVA_EXE" "java.exe"
require_file "$JAVAC_EXE" "javac.exe"
require_file "$ANDROID_JAR" "android.jar"
require_file "$BUILD_TOOLS/aapt.exe" "aapt.exe"
require_file "$BUILD_TOOLS/zipalign.exe" "zipalign.exe"
require_file "$BUILD_TOOLS/apksigner.bat" "apksigner.bat"
require_file "$BUILD_TOOLS/lib/d8.jar" "d8.jar"

build_one_abi armeabi-v7a arm32 build-android-unity
build_one_abi arm64-v8a arm64 build-android-unity-arm64
