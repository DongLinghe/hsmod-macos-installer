# Third-party notices

This repository contains installer source code, helper scripts, compatibility
patches, and launcher source code only. It does not vendor HsMod, BepInEx,
UnityDoorstop, or Hearthstone binaries.

- HsMod: https://github.com/Pik-4/HsMod
  - License observed in the source archive used for local testing: AGPL-3.0.
- BepInEx: https://github.com/BepInEx/BepInEx
  - Check upstream for the exact license of the version you use.
- UnityDoorstop: https://github.com/NeighTools/UnityDoorstop
  - License observed in the local source checkout used for testing: LGPL-2.1.
- Hearthstone is owned by Blizzard Entertainment.

The release installer app also does not bundle HsMod, BepInEx, or Hearthstone
binaries. It asks the user to select those files locally during installation.
