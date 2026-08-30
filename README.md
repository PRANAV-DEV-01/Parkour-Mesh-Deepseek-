# PARKOUR MESH

A fast-paced 2D neon parkour platformer built with **Godot 4.3**.

Run, double-jump, wall-jump and dash through three handcrafted levels of
the Mesh. Collect shards, dodge spikes, ride moving platforms, bounce off
springs and reach the portal!

![genre](https://img.shields.io/badge/genre-2D%20Platformer-blue)

## How to Run

1. Download and install [Godot 4.3+](https://godotengine.org/download) (the standard version is fine — no .NET needed).
2. Open Godot, click **Import** and select this folder's `project.godot`.
3. Press **F5** (or the Play button) to start the game.

The project uses the GL Compatibility renderer, so it runs on almost any hardware.

## Controls

| Action        | Keys                          |
|---------------|-------------------------------|
| Move          | A / D or Left / Right arrows  |
| Jump          | Space / W / Up                |
| Double jump   | Jump again in mid-air         |
| Wall slide    | Hold toward a wall while falling |
| Wall jump     | Jump while wall sliding       |
| Dash          | Shift or X                    |
| Restart level | R                             |
| Pause         | Esc                           |

On Android/iOS the game shows on-screen touch controls automatically
(move pads, jump, dash and a pause button) instead of keyboard keys.

## Running on Android

1. In Godot open **Editor → Manage Export Templates** and download the
   templates matching your Godot version.
2. Install the [Android build template / SDK setup](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)
   (Android Studio SDK + debug keystore) via **Editor → Editor Settings → Export → Android**.
3. **Project → Export → Add… → Android**, then either:
   - plug in your phone with USB debugging enabled and use the
     **one-click deploy** icon (game runs straight from the editor), or
   - click **Export Project** to get an installable APK.
4. The project is already configured for phones: GL Compatibility renderer,
   sensor-landscape orientation, fullscreen `expand` stretch mode, ETC2/ASTC
   texture compression and touch controls.

## Levels

1. **First Steps** — learn to run, jump, double-jump and ride platforms
   (watch for your first patrol drone!).
2. **Neon Heights** — vertical wall-jump climbing, crumbling bridges and a
   laser-swept summit leap.
3. **Core Runner** — dash gaps, spike corridors, spring launches, rotating
   lasers and drone-patrolled jumps.

Each level tracks your time, shard count and deaths. Beat a level to
unlock the next one (progress is saved automatically).

## Features

- Tight parkour movement: coyote time, jump buffering, variable jump height,
  double jumps, wall slides/wall jumps and an air dash (ground dashes too).
- Moving, falling (crumble) and static platforms, springs, spikes,
  checkpoints, collectible shards and goal portals.
- **Patrol drones** that sweep ledges and jump arcs — time your moves.
- **Rotating laser beams** guarding key crossings — read the sweep.
- **Shard streaks**: grab shards quickly in succession to build a combo;
  the coin pitch climbs with every link. Best streak is saved per level.
- Camera zoom punches, screen shake, respawn rings and squash & stretch.
- Fully procedural audio — every sound effect and the music loop are
  synthesized at startup, so the project needs zero external assets.
- Procedural parallax grid background and particles.
- Main menu with level select + how-to-play, pause menu, level-complete
  stats and a final results screen. Best times persist between sessions.

## Project Layout

```
Parkour Mesh/
├── project.godot        # Godot 4.3 project configuration
├── icon.svg
├── scenes/              # All scenes (.tscn)
│   ├── main_menu.tscn   # Main menu (starting scene)
│   ├── level_1..3.tscn  # The three levels
│   ├── player.tscn      # Player character
│   └── ...              # Platforms, hazards, pickups, HUD, etc.
└── scripts/             # All GDScript code (.gd)
    ├── globals.gd       # Autoload: state, saves, procedural audio
    ├── player.gd        # Parkour movement controller
    └── ...
```

Everything (visuals and audio) is generated procedurally in code, so the
project has no asset dependencies — just open and play.

Have fun, and speedrun the Mesh!
