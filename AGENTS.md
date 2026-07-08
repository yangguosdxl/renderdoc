# 仓库指南

## 项目结构与模块组织

RenderDoc 是一个使用 CMake 和 Visual Studio 工程文件构建的 C++ 图形调试器。核心捕获、回放、驱动、API 和第三方代码位于 `renderdoc/`。Qt 界面在 `qrenderdoc/`，命令行工具在 `renderdoccmd/`，注入与 shim 支持在 `renderdocshim/`。贡献文档在 `docs/CONTRIBUTING/`。测试框架和演示程序在 `util/test/`，演示源码在 `util/test/demos/`。`x64/`、`build/`、`build-android*` 等构建输出不要提交。

## 构建、测试与开发命令

- `./build-windows.sh`：使用 MSBuild 构建 `renderdoc.sln`。可通过 `CONFIGURATION`、`PLATFORM` 或 `MSBUILD_EXE` 覆盖默认值。
- `cmake -DCMAKE_BUILD_TYPE=Debug -Bbuild -H.` 后接 `make -C build`：Linux/macOS 的常规 CMake 构建。
- `cmake -DBUILD_ANDROID=On -DANDROID_ABI=armeabi-v7a -Bbuild-android -H.` 后接 `make`：构建 Android 组件。
- `cmake -Bbuild -Hdemos` 后接 `make -C build`：在 Linux/macOS 构建测试 demo；Windows 使用 `util/test/demos.sln`。
- `python util/test/run_tests.py --list`：列出 Python 测试。实际运行时通常需要传入 `--renderdoc`、`--pyrenderdoc` 和 `--demos-binary`。

## 代码风格与命名约定

遵循仓库根目录的 `.clang-format`：2 空格缩进、不使用 tab、100 列限制、指针右对齐、include 排序和自定义大括号换行。要求使用 clang-format 15.0.7，仓库内二进制位于 `util/clangformat/`。修改 C/C++ 文件后运行 `clang-format -i path/to/file.cpp` 或 `git clang-format`。避免在现有代码风格不需要时引入过新的 C++ 写法。

## 测试指南

测试目前部分依赖临场验证，但修改应覆盖受影响的图形 API、平台以及 UI/CLI 路径。优先在 `util/test/` 添加聚焦测试，并在 `util/test/demos/` 添加小型 demo；不要用一个 demo 覆盖过多行为。`run_tests.py` 会清理临时目录和 artifacts，如需保留输出，请指定 `--temp` 或 `--artifacts`。

## 提交与 Pull Request 指南

提交标题应具体且不超过 72 个字符。动机或影响不明显时添加正文。保持历史清晰：用 rebase 更新分支，不要把上游 merge 进 PR 分支；格式化或编译修复应 squash 到相关提交；最终历史中不要保留 `WIP`、`fix stuff` 或 `temp`。PR 应说明变更、列出测试过的平台/API、关联 issue，并为 UI 或渲染变更附截图或捕获文件。

## 安全与配置提示

不要讨论或添加用于捕获贡献者不拥有的第三方程序的支持路径。本地 SDK、NDK、Java、Vulkan 和 Visual Studio 路径应放在环境变量或本地脚本中，不要提交到项目文件。

## Agent 专用指令

当需要用户输入、确认或授权时，通过 `.codex/hooks.json` 中的 Codex 原生 hook 触发本地系统通知脚本。若通知失败，先检查 hook 和 `.codex/hooks/notify.ps1` 的错误信息；在合理情况下用更简单的参数重试，并说明用户需要调整的操作系统通知设置。
