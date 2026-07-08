# Patch notes

This project is not a feature fork of HsMod. It records the compatibility work
needed to make HsMod run in the tested macOS Hearthstone environment.

## HsMod compatibility build

The local build used for testing required these changes:

- Added `Microsoft.NETFramework.ReferenceAssemblies.net48` so the .NET
  Framework 4.8 project can build on macOS with `dotnet build`.
- Disabled the Windows-only `install.bat` post-build step.
- Replaced several APIs that failed in the current build/runtime environment:
  `string.Split`, `Dictionary.TryAdd`, and async file reads.
- Removed a missing `QRCoderUnity` reference.
- Changed the HsMod WebServer listener from `http://+:{port}/` to
  `http://127.0.0.1:{port}/`, because Mono on macOS rejected the wildcard
  listener address in this setup.

These changes were used to produce the local `HsMod.dll`. They are not included
as an upstream HsMod fork in this repository.

## macOS launch chain

The working launch chain required these changes:

- BepInEx 5 is installed under `/Applications/Hearthstone`.
- `HsMod.dll` is copied to `BepInEx/plugins/HsMod.dll`.
- `unstripped_corlib` is provided to avoid stripped Unity/Mono framework issues.
- The original Hearthstone binary is saved as
  `Hearthstone.app/Contents/MacOS/Hearthstone.real`.
- `Hearthstone.app/Contents/MacOS/Hearthstone` is replaced with a signed
  x86_64 Mach-O launcher wrapper.
- The wrapper sets Doorstop/BepInEx environment variables and then executes
  `Hearthstone.real`.
- Battle.net still launches `Hearthstone.app`, so login token handoff continues
  to work.

## Failed arm64e route

An `arm64e` `libdoorstop.dylib` can be compiled, and it reaches BepInEx
Preloader in this environment. However, BepInEx 5 / MonoMod.RuntimeDetour fails
during preloader patching on arm64e. The working solution therefore uses an
x86_64 wrapper and Rosetta.

## Reinject app

`HsMod Reinject.app` packages the repeatable part of the setup:

- copy the known-good HsMod/BepInEx resources,
- recreate the wrapper,
- re-sign `Hearthstone.app`,
- keep backups in `/Applications/Hearthstone/HsModBackups`,
- show a macOS alert when finished.
