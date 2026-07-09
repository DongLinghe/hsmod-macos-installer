# HsMod macOS Compatibility

[中文](#中文) | [English](#english)

## 中文

让 [HsMod](https://github.com/Pik-4/HsMod) 可以在 Apple Silicon macOS 的炉石传说上运行。

这个项目提供：

- HsMod 的 macOS 兼容补丁
- patched `HsMod.dll` 构建脚本
- BepInEx/HsMod 安装脚本
- Battle.net 可用的 macOS launcher wrapper
- 炉石更新后的快捷恢复工具

### 适用环境

- Apple Silicon Mac
- macOS 版本支持 Rosetta 2
- macOS 版 Hearthstone
- BepInEx 5 macOS universal 包
- HsMod 源码或源码 zip

已验证组合：

- macOS 27.0 beta
- Hearthstone `36.0`
- BepInEx `5.4.23.5`
- HsMod `11.3.0.2`

### 准备文件

你需要准备：

- HsMod 源码目录，或 `HsMod-bepinex5.zip`
- `BepInEx_macos_universal_5.4.23.5.zip`
- 已安装的炉石传说，默认路径：

```text
/Applications/Hearthstone/Hearthstone.app
```

### 安装

clone 两个项目：

```sh
git clone https://github.com/DongLinghe/hsmod-macos-compat.git
git clone https://github.com/Pik-4/HsMod.git
cd hsmod-macos-compat
```

运行安装脚本：

```sh
HSMOD_SOURCE=../HsMod \
BEPINEX_ZIP=/path/to/BepInEx_macos_universal_5.4.23.5.zip \
./scripts/install_from_archives.sh
```

如果不传 `HSMOD_SOURCE` 和 `BEPINEX_ZIP`，脚本会弹出文件选择框。

安装完成后，从 Battle.net 点“进入游戏”，然后打开：

```text
http://127.0.0.1:58744/pack
```

### 只构建 HsMod.dll

如果只想把 HsMod 源码打补丁并编译出 DLL：

```sh
./scripts/build_patched_hsmod.sh /path/to/HsMod-bepinex5.zip dist/HsMod.dll
```

也可以传源码目录：

```sh
./scripts/build_patched_hsmod.sh /path/to/HsMod dist/HsMod.dll
```

### 炉石更新后

炉石或 Battle.net 更新后，`Hearthstone.app` 可能会被恢复成原版。重新运行安装脚本即可：

```sh
HSMOD_SOURCE=../HsMod \
BEPINEX_ZIP=/path/to/BepInEx_macos_universal_5.4.23.5.zip \
./scripts/install_from_archives.sh
```

如果你已经安装成功过，也可以生成本机快捷工具：

```sh
./scripts/build_app_from_current_install.sh
```

生成位置：

```text
dist/HsMod macOS Helper.app
```

之后炉石更新导致 HsMod 失效时，退出炉石，双击这个 app 即可恢复当前机器上的安装。

### 恢复原版启动文件

如果要移除 launcher wrapper：

```sh
"dist/HsMod macOS Helper.app/Contents/Resources/restore_original_hearthstone.sh"
```

### 日志

```text
~/Library/Logs/HsModMacOSHelper.log
```

### 做了哪些兼容处理

HsMod 构建补丁：

- 添加 .NET Framework 4.8 reference assemblies
- 禁用 Windows `install.bat` post-build
- 修正 macOS 构建环境下不兼容的 C# API 用法
- 移除缺失的 `QRCoderUnity` 引用
- 将 HsMod WebServer 绑定到 `127.0.0.1`

完整补丁文件：

```text
patches/hsmod-macos-compat.patch
```

macOS 启动链路：

- 安装 BepInEx 5 到炉石目录
- 安装 patched `HsMod.dll`
- 安装 `unstripped_corlib`
- 保存原始炉石二进制为 `Hearthstone.real`
- 使用已签名 x86_64 launcher wrapper 启动原始游戏
- 保留 Battle.net 登录 token 传递

`arm64e` Doorstop 可以编译，但 BepInEx 5 / MonoMod.RuntimeDetour 在 arm64e 预加载阶段失败。当前可用方案使用 Rosetta/x86_64 wrapper。

### 上游项目

- HsMod: https://github.com/Pik-4/HsMod
- BepInEx: https://github.com/BepInEx/BepInEx
- UnityDoorstop: https://github.com/NeighTools/UnityDoorstop

### 注意

这个项目会修改本机的 `Hearthstone.app` 启动文件，并在炉石目录下创建备份。使用前请退出炉石。

## English

Run [HsMod](https://github.com/Pik-4/HsMod) on Apple Silicon macOS Hearthstone.

This project provides:

- macOS compatibility patches for HsMod
- a script for building a patched `HsMod.dll`
- a BepInEx/HsMod installer script
- a Battle.net-compatible macOS launcher wrapper
- an optional helper app for restoring the setup after Hearthstone updates

### Requirements

- Apple Silicon Mac
- macOS with Rosetta 2
- macOS Hearthstone
- BepInEx 5 macOS universal package
- HsMod source tree or source zip

Tested with:

- macOS 27.0 beta
- Hearthstone `36.0`
- BepInEx `5.4.23.5`
- HsMod `11.3.0.2`

### Files You Need

- HsMod source directory, or `HsMod-bepinex5.zip`
- `BepInEx_macos_universal_5.4.23.5.zip`
- Hearthstone installed at the default path:

```text
/Applications/Hearthstone/Hearthstone.app
```

### Install

Clone both repositories:

```sh
git clone https://github.com/DongLinghe/hsmod-macos-compat.git
git clone https://github.com/Pik-4/HsMod.git
cd hsmod-macos-compat
```

Run the installer:

```sh
HSMOD_SOURCE=../HsMod \
BEPINEX_ZIP=/path/to/BepInEx_macos_universal_5.4.23.5.zip \
./scripts/install_from_archives.sh
```

If `HSMOD_SOURCE` and `BEPINEX_ZIP` are omitted, the script opens file pickers.

After installation, launch Hearthstone from Battle.net and open:

```text
http://127.0.0.1:58744/pack
```

### Build HsMod.dll Only

Build a patched DLL from a source zip:

```sh
./scripts/build_patched_hsmod.sh /path/to/HsMod-bepinex5.zip dist/HsMod.dll
```

Or from a source directory:

```sh
./scripts/build_patched_hsmod.sh /path/to/HsMod dist/HsMod.dll
```

### After Hearthstone Updates

Hearthstone or Battle.net updates may restore the original `Hearthstone.app`.
Run the installer again:

```sh
HSMOD_SOURCE=../HsMod \
BEPINEX_ZIP=/path/to/BepInEx_macos_universal_5.4.23.5.zip \
./scripts/install_from_archives.sh
```

You can also build a local helper app after a successful install:

```sh
./scripts/build_app_from_current_install.sh
```

Output:

```text
dist/HsMod macOS Helper.app
```

When an update breaks the setup, quit Hearthstone and run this helper app to
restore the current machine's installation.

### Restore Original Launcher

```sh
"dist/HsMod macOS Helper.app/Contents/Resources/restore_original_hearthstone.sh"
```

### Logs

```text
~/Library/Logs/HsModMacOSHelper.log
```

### Compatibility Changes

HsMod build patch:

- adds .NET Framework 4.8 reference assemblies
- disables the Windows `install.bat` post-build step
- fixes C# API usage that fails in the macOS build environment
- removes the missing `QRCoderUnity` reference
- binds the HsMod WebServer to `127.0.0.1`

Patch file:

```text
patches/hsmod-macos-compat.patch
```

macOS launch flow:

- installs BepInEx 5 into the Hearthstone directory
- installs the patched `HsMod.dll`
- installs `unstripped_corlib`
- saves the original Hearthstone binary as `Hearthstone.real`
- launches the original game through a signed x86_64 wrapper
- keeps Battle.net login token handoff working

An `arm64e` Doorstop build can be produced, but BepInEx 5 /
MonoMod.RuntimeDetour fails during arm64e preloading. The working path uses a
Rosetta/x86_64 wrapper.

### Upstream Projects

- HsMod: https://github.com/Pik-4/HsMod
- BepInEx: https://github.com/BepInEx/BepInEx
- UnityDoorstop: https://github.com/NeighTools/UnityDoorstop

### Note

This project modifies the local `Hearthstone.app` launcher and creates backups
in the Hearthstone directory. Quit Hearthstone before running the installer.
