#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$SCRIPT_DIR"

CONFIGURATION=${CONFIGURATION:-Release}
PLATFORM=${PLATFORM:-x64}
PLATFORM_TOOLSET=${PLATFORM_TOOLSET:-v143}
MSBUILD_EXE=${MSBUILD_EXE:-C:/Program Files/Microsoft Visual Studio/2022/Community/MSBuild/Current/Bin/amd64/MSBuild.exe}

if [ ! -f "$MSBUILD_EXE" ]; then
  echo "MSBuild not found: $MSBUILD_EXE" >&2
  echo "Set MSBUILD_EXE to the correct MSBuild.exe path." >&2
  exit 1
fi

"$MSBUILD_EXE" renderdoc.sln /m \
  "/p:Configuration=$CONFIGURATION" \
  "/p:Platform=$PLATFORM" \
  "/p:PlatformToolset=$PLATFORM_TOOLSET"

echo "Windows build output:"
ls -lh \
  "x64/$CONFIGURATION/qrenderdoc.exe" \
  "x64/$CONFIGURATION/renderdoc.dll" \
  "x64/$CONFIGURATION/renderdoccmd.exe"
