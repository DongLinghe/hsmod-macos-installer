# About

HsMod macOS Reinject is an unofficial macOS compatibility and reinject helper
for running HsMod with BepInEx on Hearthstone.

The upstream HsMod package is not directly usable in the tested Apple Silicon
macOS Hearthstone setup. This project documents the compatibility work needed
to build/load HsMod locally, then packages the macOS launch-wrapper and
reinject flow into a small app.

It is intentionally kept separate from HsMod itself because it does not change
HsMod gameplay features. It manages the macOS launch wrapper, BepInEx resource
layout, app re-signing, and post-update reinjection flow needed for this tested
setup.

Repository description suggestion:

```text
Unofficial macOS compatibility and reinject helper for HsMod/BepInEx on Hearthstone.
```
