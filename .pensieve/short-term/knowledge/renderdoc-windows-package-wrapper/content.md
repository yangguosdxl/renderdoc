---
id: renderdoc-windows-package-wrapper
type: knowledge
title: RenderDoc Windows 本地打包包装脚本
status: draft
created: 2026-07-08
updated: 2026-07-08
tags: [renderdoc, windows, packaging, build-script]
---

# RenderDoc Windows 本地打包包装脚本

## Source

- 根目录包装脚本：`build-package.sh`
- 官方入口：`util/buildscripts/build.sh`
- Windows 打包实现：`util/buildscripts/scripts/make_package_win32.sh`

## Summary

Windows 本地打包应通过根目录 `build-package.sh` 配置本机工具链环境，再调用官方
`util/buildscripts/build.sh`，避免直接修改官方打包逻辑。

## Content

`build-package.sh` 负责配置以下本机环境：

- `MSBUILD_EXE`
- `ANDROID_SDK`
- `ANDROID_NDK`
- `JAVA_HOME`
- `WIX`
- `ANDROID_BUILD_TOOLS_VERSION`
- `APK_TARGET_ID`

官方 Windows 打包脚本要求同时存在 `x64/Release` 和 `Win32/Release`。如果只存在
`x64/Release`，`--skipcompile` 打包会停止在：

```text
ERROR: Missing one of Win32 or x64 Release builds
```

当前环境没有 `zip` 命令，但有 `C:/Program Files/7-Zip/7z.exe`。包装脚本在缺少 `zip`
时会导出一个兼容 `zip -r <包名.zip> <目录>/` 的 bash 函数，内部调用 7-Zip。

MSVC 默认按系统代码页读取源码。包装脚本导出 `CL=/utf-8`，否则包含 UTF-8 中文注释的
`renderdoc/android/android.cpp` 会触发 C4819，并因 `/WX` 升级为 C2220 导致编译失败。

`./build-package.sh --snapshot local-v1.x-20260708` 已验证可生成：

```text
package/RenderDoc_local-v1.x-20260708_32.zip
package/RenderDoc_local-v1.x-20260708_64.zip
```

当前本机仍缺少 WiX、CHM 文档和 GPG 私钥，因此 MSI、CHM 和 `.sig` 签名文件不会生成。

## When to Use

需要在 Windows/MSYS 环境下打包 RenderDoc 发布包，或者诊断 `build.sh --skipcompile`
为什么无法生成 `package/` 时，先读取这条知识。
