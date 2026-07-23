# Patch Notes

This project is an installer and compatibility layer for HsMod on Apple Silicon
macOS Hearthstone. It does not change HsMod gameplay features.

## HsMod Build Compatibility

- Added `Microsoft.NETFramework.ReferenceAssemblies.net48` so the .NET
  Framework 4.8 project can build on macOS with `dotnet build`.
- Disabled the Windows-only `install.bat` post-build step.
- Replaced API usage that failed in the tested macOS build/runtime path:
  `string.Split`, `Dictionary.TryAdd`, and async file reads.
- Removed a missing `QRCoderUnity` reference.
- Changed the HsMod WebServer listener from `http://+:{port}/` to
  `http://127.0.0.1:{port}/`.

The patch is stored at:

```text
patches/hsmod-macos-compat.patch
```

## macOS Launch Chain

- BepInEx 5 is installed under the Hearthstone directory.
- `HsMod.dll` is copied to `BepInEx/plugins/HsMod.dll`.
- `unstripped_corlib` is installed for the Unity/Mono runtime path.
- The original Hearthstone executable is saved as
  `Hearthstone.app/Contents/MacOS/Hearthstone.real`.
- `Hearthstone.app/Contents/MacOS/Hearthstone` is replaced with a signed
  x86_64 launcher wrapper.
- The wrapper sets Doorstop/BepInEx environment variables and then launches
  `Hearthstone.real`.
- Battle.net launch and login arguments are forwarded to the real game binary.

## Why Rosetta

An `arm64e` Doorstop path can reach BepInEx Preloader in the tested
environment, but BepInEx 5 / MonoMod.RuntimeDetour fails during preloader
patching. The working installer path therefore uses an x86_64 launcher wrapper
and Rosetta.

## Installer App

`HsMod macOS Installer.app` packages this project's scripts, launcher source,
templates, and patch file. It does not package HsMod, BepInEx, or Hearthstone
binaries. During installation it asks the user to select those inputs, builds
the patched `HsMod.dll`, injects BepInEx/HsMod into the selected Hearthstone
installation, and signs the modified app bundle locally.
