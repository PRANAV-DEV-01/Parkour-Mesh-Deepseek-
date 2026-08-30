# Parkour Mesh — Release Notes

## v1.0.0 (release)

The first full release of the neon parkour platformer.

### New in v1.0.0

- **Six full levels** (up from three):
  1. First Steps
  2. Neon Heights
  3. Core Runner
  4. Crystal Caves
  5. Tower Ascent
  6. The Gauntlet
- **Progression & star ratings** — beat a level to unlock the next; collect
  shards for a 1–3 star rating shown on the level select. Progress, best
  times, shards and deaths persist automatically between sessions.
- **Visuals & polish**
  - Procedural neon gradient sky behind the animated parallax grid.
  - Camera shake on dash, death, landing and wall-jump.
  - Dash trail VFX, landing dust and squash & stretch.
- **Audio** — fully procedural: jump, double-jump, wall-jump, dash, land,
  shard collect, checkpoint, death, spring, crumble, goal/win sound effects
  and a looping synthwave background track. No external assets required.
- **UI** — main menu, level select with locks + stars, pause menu, in-game
  HUD, level-complete stats and a final results screen.

### Platforms

- Web (HTML5)
- Windows
- Linux
- Android

### Controls

- **Move**: A / D or Left / Right
- **Jump**: Space / W / Up (double-jump; wall-jump while sliding)
- **Dash**: Shift or X
- **Restart**: R
- **Pause**: Esc

### Build

Rebuilds are automated via GitHub Actions (see `.github/workflows/build.yml`).
Push a `v*` tag to publish a GitHub Release with binaries attached.
