# T30 · Free walk breaks when the window changes

Phase 2 · Target: Aash · Risk: medium · Detail: outline

## Goal

The free walk keeps working after the frontmost window or app changes (switching apps, Spaces or
full-screen windows). Today it breaks: the user reported it during the T28 manual check.

## Notes for `/plan-phase 2`

- Not reproduced yet; find out what "breaks" means (buddy vanishes, stops, walks over menus, stays out).
- Suspects: `FreeWalkStage.rescan()` after app activation and Space changes, stale `homeScreenX`
  or plan, menu frames not yet updated when the rescan runs.
- T28 made `rescan()` report `plan?.visible` (not the far-left band) so an app switch doesn't send
  the buddy home early; keep that unless the fix needs otherwise.
- Needs a manual check that switches apps during a walk.
