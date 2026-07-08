#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$SCRIPT_DIR"

DEFAULT_MSBUILD_EXE="C:/Program Files/Microsoft Visual Studio/2022/Community/MSBuild/Current/Bin/amd64/MSBuild.exe"
DEFAULT_ANDROID_SDK="D:/Program Files/Unity 2021.3.43f1/Editor/Data/PlaybackEngines/AndroidPlayer/SDK"
DEFAULT_ANDROID_NDK="G:/Android/android-ndk-r14b-windows-x86_64/android-ndk-r14b"
DEFAULT_JAVA_HOME="D:/Program Files/Unity 2021.3.43f1/Editor/Data/PlaybackEngines/AndroidPlayer/OpenJDK"
DEFAULT_WIX="C:/Program Files (x86)/WiX Toolset v3.11"

MSBUILD_EXE=${MSBUILD_EXE:-$DEFAULT_MSBUILD_EXE}
ANDROID_SDK=${ANDROID_SDK:-$DEFAULT_ANDROID_SDK}
ANDROID_NDK=${ANDROID_NDK:-$DEFAULT_ANDROID_NDK}
JAVA_HOME=${JAVA_HOME:-$DEFAULT_JAVA_HOME}
ANDROID_BUILD_TOOLS_VERSION=${ANDROID_BUILD_TOOLS_VERSION:-32.0.0}
APK_TARGET_ID=${APK_TARGET_ID:-android-30}
WIX=${WIX:-$DEFAULT_WIX}

log() {
  printf '[打包] %s\n' "$*"
}

warn() {
  printf '[打包][警告] %s\n' "$*" >&2
}

die() {
  printf '[打包][错误] %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
用法：
  ./build-package.sh
  ./build-package.sh --snapshot <名称> --skipcompile
  ./build-package.sh --official --skipcompile

默认行为：
  不传参数时，使用当前分支和日期生成本地快照名，并调用：
  util/buildscripts/build.sh --snapshot <本地快照名> --skipcompile

常用环境变量：
  MSBUILD_EXE                 MSBuild.exe 路径
  ANDROID_SDK                 Android SDK 路径
  ANDROID_NDK                 Android NDK 路径
  JAVA_HOME                   JDK 路径
  WIX                         WiX 根目录，要求存在 bin/candle.exe 和 bin/light.exe
  SEVEN_ZIP                   7z.exe 路径；缺少 zip 命令时自动用它代替
  ANDROID_BUILD_TOOLS_VERSION Android build-tools 版本，默认 32.0.0
  APK_TARGET_ID               Android 平台 ID，默认 android-30

输出目录：
  package/

说明：
  本脚本只配置本机环境并包装官方 util/buildscripts/build.sh。
  真正的打包逻辑仍由官方脚本执行。
EOF
}

to_unix_path() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -u "$1"
  else
    printf '%s\n' "$1"
  fi
}

add_path_dir() {
  local dir=$1
  if [ -d "$dir" ]; then
    PATH="$(to_unix_path "$dir"):$PATH"
  fi
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "缺少命令：$1"
}

configure_zip_command() {
  if command -v zip >/dev/null 2>&1; then
    log "zip：$(command -v zip)"
    return
  fi

  SEVEN_ZIP=${SEVEN_ZIP:-}
  if [ -z "$SEVEN_ZIP" ] && [ -f "C:/Program Files/7-Zip/7z.exe" ]; then
    SEVEN_ZIP="C:/Program Files/7-Zip/7z.exe"
  fi
  if [ -z "$SEVEN_ZIP" ] && [ -f "C:/Program Files (x86)/7-Zip/7z.exe" ]; then
    SEVEN_ZIP="C:/Program Files (x86)/7-Zip/7z.exe"
  fi

  if [ ! -f "$SEVEN_ZIP" ]; then
    die "缺少命令：zip，且没有找到可替代的 7z.exe"
  fi

  export SEVEN_ZIP

  # 官方 Windows 打包脚本只使用 zip -r <包名.zip> <目录>/，这里用 7-Zip 兼容该用法。
  zip() {
    if [ "${1:-}" != "-r" ]; then
      "$SEVEN_ZIP" a -tzip "$@"
      return
    fi

    shift
    local archive=$1
    shift
    "$SEVEN_ZIP" a -tzip "$archive" "$@"
  }

  export -f zip
  log "zip：使用 7-Zip 兼容模式，路径 $SEVEN_ZIP"
}

check_file() {
  local label=$1
  local path=$2
  if [ -f "$path" ]; then
    log "$label：$path"
  else
    warn "$label 不存在：$path"
  fi
}

check_dir() {
  local label=$1
  local path=$2
  if [ -d "$path" ]; then
    log "$label：$path"
  else
    warn "$label 不存在：$path"
  fi
}

make_default_args() {
  local branch
  local today
  branch=$(git branch --show-current 2>/dev/null || true)
  if [ -z "$branch" ]; then
    branch=$(git rev-parse --short HEAD 2>/dev/null || printf 'unknown')
  fi
  branch=$(printf '%s' "$branch" | tr -c 'A-Za-z0-9._-' '-')
  today=$(date +%Y%m%d)
  printf '%s\n' "--snapshot" "local-${branch}-${today}" "--skipcompile"
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

MSBUILD_DIR=$(dirname "$MSBUILD_EXE")
BUILD_TOOLS="$ANDROID_SDK/build-tools/$ANDROID_BUILD_TOOLS_VERSION"

export MSBUILD_EXE
export ANDROID_SDK
export ANDROID_SDK_ROOT="$ANDROID_SDK"
export ANDROID_HOME="$ANDROID_SDK"
export ANDROID_NDK
export ANDROID_NDK_ROOT="$ANDROID_NDK"
export JAVA_HOME
export ANDROID_BUILD_TOOLS_VERSION
export APK_TARGET_ID
export WIX
export GPG_TTY=${GPG_TTY:-$(tty 2>/dev/null || true)}

add_path_dir "$MSBUILD_DIR"
add_path_dir "$JAVA_HOME/bin"
add_path_dir "$ANDROID_SDK/cmake/3.22.1/bin"
add_path_dir "$BUILD_TOOLS"
add_path_dir "$WIX/bin"
export PATH

# MSVC 默认按系统代码页读取源码；包装脚本中显式使用 UTF-8，避免中文注释触发 C4819。
case " ${CL:-} " in
  *" /utf-8 "*) ;;
  *) export CL="${CL:-} /utf-8" ;;
esac

log "开始检查本地打包环境"
check_file "MSBuild" "$MSBUILD_EXE"
check_dir "Android SDK" "$ANDROID_SDK"
check_dir "Android NDK" "$ANDROID_NDK"
check_dir "JDK" "$JAVA_HOME"
check_dir "WiX" "$WIX"
check_file "WiX candle" "$WIX/bin/candle.exe"
check_file "WiX light" "$WIX/bin/light.exe"

require_command bash
require_command git
require_command gpg
configure_zip_command

if [ ! -d x64/Release ] || [ ! -d Win32/Release ]; then
  warn "官方 Windows 打包要求同时存在 x64/Release 和 Win32/Release"
fi

if [ ! -d Documentation/htmlhelp ]; then
  warn "未找到 Documentation/htmlhelp，安装包内可能缺少 CHM 帮助文档"
fi

if [ "$#" -eq 0 ]; then
  mapfile -t BUILD_ARGS < <(make_default_args)
else
  BUILD_ARGS=("$@")
fi

log "调用官方打包脚本：util/buildscripts/build.sh ${BUILD_ARGS[*]}"
bash util/buildscripts/build.sh "${BUILD_ARGS[@]}"

if find package -maxdepth 1 -type f \( -name '*.zip' -o -name '*.tar.gz' -o -name '*.dmg' \) -print -quit 2>/dev/null | grep -q .; then
  log "打包完成，输出目录：$SCRIPT_DIR/package"
  find package -maxdepth 1 -type f -print
else
  die "官方脚本结束后没有发现发布包文件，请查看上方日志"
fi
