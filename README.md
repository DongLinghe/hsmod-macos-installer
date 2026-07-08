# HsMod macOS Reinject

一个给 macOS 炉石传说用的 HsMod 重注入小工具。

它不是 HsMod 官方项目，也不是 HsMod 的功能 fork。它只解决一个很具体的问题：Battle.net 或炉石更新后，`Hearthstone.app` 经常会被修回原版，导致 BepInEx/HsMod 注入失效；这个工具可以把当前已验证可用的 HsMod/BepInEx 资源重新装回去，并重新给炉石套上一个已签名的 x86_64 launcher wrapper。

上游项目：

- HsMod: https://github.com/Pik-4/HsMod
- BepInEx: https://github.com/BepInEx/BepInEx
- UnityDoorstop: https://github.com/NeighTools/UnityDoorstop

## 为什么不是 fork HsMod

这个仓库不改 HsMod 的核心逻辑。它做的是 macOS 启动链路：

1. Battle.net 仍然正常启动 `Hearthstone.app`，所以登录 token 由 Battle.net 正常传给游戏。
2. `Hearthstone.app/Contents/MacOS/Hearthstone` 会被替换成一个已签名的 x86_64 wrapper。
3. wrapper 设置 Doorstop/BepInEx 环境变量。
4. wrapper 再执行原始游戏二进制 `Hearthstone.real`。
5. BepInEx 加载 `BepInEx/plugins/HsMod.dll`。

所以它更适合做成单独 helper，而不是 fork HsMod。

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
