# HsMod macOS Reinject

一个让 HsMod 在 macOS 炉石传说上可用的兼容启动/重注入小工具。

现有 HsMod 上游包主要面向 Windows/BepInEx 使用场景，在当前 macOS Apple Silicon 炉石链路里不能直接开箱即用。直接使用常见的 macOS BepInEx 启动脚本会遇到架构、签名、Battle.net 登录 token 和 HsMod WebServer 绑定等问题。

这个仓库不是 HsMod 官方项目，也不是 HsMod 的功能 fork。它记录并封装了一套在本机验证成功的 macOS 兼容方案：构建/准备可用的 HsMod/BepInEx 资源，然后通过一个已签名的 x86_64 launcher wrapper 让 Battle.net 仍然正常启动炉石，同时注入 BepInEx/HsMod。

它还提供一个 `HsMod Reinject.app`：Battle.net 或炉石更新后，如果 `Hearthstone.app` 被修回原版，双击这个 app 就能把当前已验证可用的 HsMod/BepInEx 资源重新装回去。

上游项目：

- HsMod: https://github.com/Pik-4/HsMod
- BepInEx: https://github.com/BepInEx/BepInEx
- UnityDoorstop: https://github.com/NeighTools/UnityDoorstop

## 为什么不是 fork HsMod

这个仓库不改 HsMod 的玩法功能，也不维护 HsMod 的上游代码分支。它做的是 macOS 启动链路和重注入工具：

1. Battle.net 仍然正常启动 `Hearthstone.app`，所以登录 token 由 Battle.net 正常传给游戏。
2. `Hearthstone.app/Contents/MacOS/Hearthstone` 会被替换成一个已签名的 x86_64 wrapper。
3. wrapper 设置 Doorstop/BepInEx 环境变量。
4. wrapper 再执行原始游戏二进制 `Hearthstone.real`。
5. BepInEx 加载 `BepInEx/plugins/HsMod.dll`。

所以它更适合做成单独 helper，而不是 fork HsMod。

## 为了跑通改了什么

这套方案分成两部分：本地 HsMod 兼容构建，以及 macOS 启动/重注入。

本地 HsMod 兼容构建时做过这些处理：

- 给 .NET Framework 4.8 项目补 `Microsoft.NETFramework.ReferenceAssemblies.net48`，让它能在 macOS 上用 `dotnet build` 编译。
- 禁用 Windows 专用的 `install.bat` post-build 步骤。
- 修正若干在当前编译环境下不兼容的 C# API 用法，例如 `string.Split`、`Dictionary.TryAdd`、异步文件读取等。
- 移除缺失的 `QRCoderUnity` 引用。
- 将 HsMod 内置 WebServer 从 `http://+:{port}/` 改为 `http://127.0.0.1:{port}/`，避免 macOS/Mono 上地址绑定失败。

macOS 启动/注入链路做了这些处理：

- 安装 BepInEx 5 到 `/Applications/Hearthstone`。
- 将构建出的 `HsMod.dll` 放到 `BepInEx/plugins/HsMod.dll`。
- 补齐 `BepInEx/unstripped_corlib`，避免 Unity/Mono 运行时缺少完整 corlib。
- 直接用 shell wrapper 替换 `Hearthstone.app` 会导致 macOS `Code Signature Invalid` 闪退，所以改为编译一个真正的 Mach-O x86_64 launcher wrapper。
- wrapper 会设置 Doorstop/BepInEx 所需环境变量，再执行原始炉石二进制 `Hearthstone.real`。
- 保留 Battle.net 启动入口，让 Battle.net 继续传递 `-launch -uid hs_beta` 和登录 token；这比直接运行 `run_bepinex.sh` 稳定。
- 尝试过编译 `arm64e` 的 `libdoorstop.dylib`，但 BepInEx 5 的 `MonoMod.RuntimeDetour` 在 arm64e 预加载阶段失败，所以最终采用 Rosetta/x86_64 wrapper 方案。
- 做了 `HsMod Reinject.app`，用于炉石更新后重新复制资源、重建 wrapper、重签名 `Hearthstone.app`。

也就是说：没有修改 HsMod 的卡牌/皮肤/功能逻辑；改的是让它能在这个 macOS 启动环境里编译、加载、登录和保持 Web UI 可访问的兼容层。

## 已验证环境

- macOS 27.0 beta
- Apple Silicon Mac
- Hearthstone `36.0`
- BepInEx `5.4.23.5`
- HsMod `11.3.0.2`

其他版本不保证一定可用。

## 已安装用户怎么用

如果你已经拿到了构建好的 `HsMod Reinject.app`：

1. 退出炉石。
2. 双击 `HsMod Reinject.app`。
3. 等提示“注入完成”。
4. 回到 Battle.net，点“进入游戏”。
5. 打开 `http://127.0.0.1:58744/pack` 查看 HsMod 页面。

日志位置：

```text
~/Library/Logs/HsModReinject.log
```

如果炉石更新后 HsMod 失效，重复上面流程即可。

## 从当前已安装环境构建 app

这个仓库默认不提交第三方二进制。构建脚本会从你本机当前炉石安装目录里复制这些资源：

- `/Applications/Hearthstone/BepInEx/plugins/HsMod.dll`
- `/Applications/Hearthstone/libdoorstop.dylib`
- `/Applications/Hearthstone/BepInEx/unstripped_corlib`
- `~/Downloads/BepInEx_macos_universal_5.4.23.5.zip`

然后生成：

```text
dist/HsMod Reinject.app
```

构建命令：

```sh
./scripts/build_app_from_current_install.sh
```

如果 BepInEx zip 不在默认下载目录：

```sh
BEPINEX_ZIP=/path/to/BepInEx_macos_universal_5.4.23.5.zip ./scripts/build_app_from_current_install.sh
```

如果炉石不在默认目录：

```sh
HEARTHSTONE_ROOT=/path/to/Hearthstone ./scripts/build_app_from_current_install.sh
```

## 手动重注入

构建后可以直接运行 app 内脚本：

```sh
"dist/HsMod Reinject.app/Contents/MacOS/reinject_current_hsmod.sh"
```

或者复制到 `/Applications` 后双击：

```sh
ditto "dist/HsMod Reinject.app" "/Applications/HsMod Reinject.app"
```

## 恢复原版启动文件

如果想取消 wrapper：

```sh
"dist/HsMod Reinject.app/Contents/Resources/restore_original_hearthstone.sh"
```

它会把 `Hearthstone.real` 放回 `Hearthstone`，并重新签名 `Hearthstone.app`。

## 注意

- 运行重注入前必须退出炉石。
- Battle.net 更新或炉石修复可能会覆盖注入结果。
- 这个工具会修改 `/Applications/Hearthstone/Hearthstone.app`，并在 `/Applications/Hearthstone/HsModBackups` 留备份。
- 不保证符合 Blizzard/Battle.net 的服务条款；请自行承担使用风险。
