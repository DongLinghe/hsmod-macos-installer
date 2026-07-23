# HsMod macOS Installer

[中文](#中文) | [English](#english)

## 中文

一个用于 Apple Silicon macOS 炉石传说的 HsMod 图形安装器。

原版 HsMod 的发布包主要面向 Windows/BepInEx 使用方式，直接放到 macOS 炉石里会遇到 Doorstop 架构、BepInEx 预加载、.NET Framework 构建和 Battle.net 启动文件恢复等问题。这个项目提供 macOS 兼容补丁、启动 wrapper 和一个 `.app` 安装器，让 HsMod 可以在 Apple Silicon Mac 上通过 Rosetta 跑起来。

### 下载

从 GitHub Releases 下载：

```text
HsMod-macOS-Installer.zip
```

解压后打开：

```text
HsMod macOS Installer.app
```

### 你需要准备

- HsMod 源码目录，或 HsMod 源码 zip，例如 `HsMod-bepinex5.zip`
- BepInEx 5 macOS universal zip，例如 `BepInEx_macos_universal_5.4.23.5.zip`
- 已安装的 macOS 版炉石传说，通常是：

```text
/Applications/Hearthstone/Hearthstone.app
```

### 使用方法

1. 打开 `HsMod macOS Installer.app`
2. 在 `HsMod` 里选择 HsMod 源码目录或源码 zip
3. 在 `BepInEx` 里选择 BepInEx macOS universal zip
4. 在 `Hearthstone` 里选择 `Hearthstone.app`，或者选择 `/Applications/Hearthstone` 文件夹
5. 点击 `Install`
6. 安装完成后，安装器会打开 Battle.net；从 Battle.net 点“进入游戏”
7. 游戏进入后打开：

```text
http://127.0.0.1:58744/pack
```

如果炉石更新或 Battle.net 校验后 HsMod 失效，退出炉石，重新打开安装器，点 `Re-inject`，然后马上从 Battle.net 启动游戏。

### 安装器会做什么

- 给 HsMod 源码应用 `patches/hsmod-macos-compat.patch`
- 在 macOS 上构建 patched `HsMod.dll`
- 解压 BepInEx 到炉石目录
- 安装 `BepInEx/plugins/HsMod.dll`
- 安装 HsMod 需要的 `unstripped_corlib`
- 保存原始炉石二进制为 `Hearthstone.real`
- 用签名后的 x86_64 launcher wrapper 替换炉石启动文件
- 重新签名 `Hearthstone.app`

### 兼容改动

HsMod 构建侧：

- 添加 .NET Framework 4.8 reference assemblies，方便在 macOS 用 `dotnet build`
- 禁用 Windows-only `install.bat` post-build
- 修正当前 macOS 构建/运行环境里不兼容的 C# API 用法
- 移除缺失的 `QRCoderUnity` 引用
- 将 HsMod WebServer 绑定到 `127.0.0.1`

macOS 启动侧：

- 保留 Battle.net 启动时传入的登录参数
- 使用 x86_64 wrapper 进入 Rosetta 路径
- 通过 Doorstop/BepInEx 加载 HsMod

`arm64e` Doorstop 可以进入预加载阶段，但 BepInEx 5 / MonoMod.RuntimeDetour 在这个路径下会失败。当前可用方案是 x86_64 wrapper + Rosetta。

### 从源码构建安装器

```sh
git clone https://github.com/DongLinghe/hsmod-macos-installer.git
cd hsmod-macos-installer
./scripts/build_installer_app.sh
```

输出：

```text
dist/HsMod macOS Installer.app
```

打包 Release zip：

```sh
./scripts/package_release.sh
```

输出：

```text
dist/HsMod-macOS-Installer.zip
```

### 日志和恢复

安装日志：

```text
~/Library/Logs/HsModMacOSHelper.log
```

安装器会在炉石目录创建备份：

```text
/Applications/Hearthstone/HsModBackups
```

恢复原版启动文件：

```sh
./scripts/restore_original_hearthstone.sh /Applications/Hearthstone/Hearthstone.app
```

### 上游项目

- HsMod: https://github.com/Pik-4/HsMod
- BepInEx: https://github.com/BepInEx/BepInEx
- UnityDoorstop: https://github.com/NeighTools/UnityDoorstop

## English

A GUI installer for running HsMod on Apple Silicon macOS Hearthstone.

The upstream HsMod package is primarily arranged for the Windows/BepInEx flow. On macOS Hearthstone, direct installation hits Doorstop architecture issues, BepInEx preload issues, .NET Framework build friction, and Battle.net executable restoration. This project ships macOS compatibility patches, a launch wrapper, and a `.app` installer so HsMod can run on Apple Silicon Macs through Rosetta.

### Download

Download this file from GitHub Releases:

```text
HsMod-macOS-Installer.zip
```

Unzip it and open:

```text
HsMod macOS Installer.app
```

### Files You Need

- HsMod source directory, or a source zip such as `HsMod-bepinex5.zip`
- BepInEx 5 macOS universal zip, such as `BepInEx_macos_universal_5.4.23.5.zip`
- macOS Hearthstone, usually installed at:

```text
/Applications/Hearthstone/Hearthstone.app
```

### Usage

1. Open `HsMod macOS Installer.app`
2. Select the HsMod source directory or source zip
3. Select the BepInEx macOS universal zip
4. Select `Hearthstone.app`, or the `/Applications/Hearthstone` folder
5. Click `Install`
6. When installation finishes, the installer opens Battle.net; launch Hearthstone from Battle.net
7. After the game starts, open:

```text
http://127.0.0.1:58744/pack
```

If Hearthstone updates or Battle.net restores the official executable, quit Hearthstone, open the installer again, click `Re-inject`, then launch the game from Battle.net immediately.

### What The Installer Does

- Applies `patches/hsmod-macos-compat.patch` to the HsMod source
- Builds a patched `HsMod.dll` on macOS
- Extracts BepInEx into the Hearthstone directory
- Installs `BepInEx/plugins/HsMod.dll`
- Installs the `unstripped_corlib` files required by HsMod
- Saves the original Hearthstone binary as `Hearthstone.real`
- Replaces the Hearthstone executable with a signed x86_64 launcher wrapper
- Re-signs `Hearthstone.app`

### Compatibility Changes

HsMod build changes:

- Add .NET Framework 4.8 reference assemblies for `dotnet build` on macOS
- Disable the Windows-only `install.bat` post-build step
- Adjust C# API usage that fails in the tested macOS build/runtime path
- Remove a missing `QRCoderUnity` reference
- Bind the HsMod WebServer to `127.0.0.1`

macOS launch changes:

- Preserve Battle.net launch/login arguments
- Use an x86_64 wrapper to enter the Rosetta path
- Load HsMod through Doorstop/BepInEx

An `arm64e` Doorstop path can reach the preload stage, but BepInEx 5 / MonoMod.RuntimeDetour fails there. The working path is x86_64 wrapper + Rosetta.

### Build From Source

```sh
git clone https://github.com/DongLinghe/hsmod-macos-installer.git
cd hsmod-macos-installer
./scripts/build_installer_app.sh
```

Output:

```text
dist/HsMod macOS Installer.app
```

Package the release zip:

```sh
./scripts/package_release.sh
```

Output:

```text
dist/HsMod-macOS-Installer.zip
```

### Logs And Recovery

Install log:

```text
~/Library/Logs/HsModMacOSHelper.log
```

Backups are created under:

```text
/Applications/Hearthstone/HsModBackups
```

Restore the original launcher:

```sh
./scripts/restore_original_hearthstone.sh /Applications/Hearthstone/Hearthstone.app
```

### Upstream Projects

- HsMod: https://github.com/Pik-4/HsMod
- BepInEx: https://github.com/BepInEx/BepInEx
- UnityDoorstop: https://github.com/NeighTools/UnityDoorstop
