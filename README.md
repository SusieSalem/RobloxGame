# HFF-style movement (R15)

Human Fall Flat / Gang Beasts style physics movement for R15 characters.

## Files

Synced with Rojo (`default.project.json`, port 34872). Each folder is the Roblox service it syncs into:

| File | In Studio | What it does |
| --- | --- | --- |
| `ReplicatedStorage/HFFMovementConfig.luau` | ModuleScript `ReplicatedStorage.HFFMovementConfig` | Every tunable value |
| `ServerScriptService/HFFServer.server.luau` | Script `ServerScriptService.HFFServer` | Ragdoll setup, network ownership, grips |
| `ServerScriptService/HFFPlayground.server.luau` | Script `ServerScriptService.HFFPlayground` | Optional test area. Off via `SpawnPlayground = false` |
| `StarterPlayer/StarterPlayerScripts/HFFClient.client.luau` | LocalScript `StarterPlayerScripts.HFFClient` | Entry point: wires the modules below together |
| `StarterPlayer/StarterPlayerScripts/HFF/` | Folder of ModuleScripts | Movement logic, one job per file (see below) |
| `StarterPlayer/StarterPlayerScripts/UI/` | Folder of ModuleScripts | The HUD, one piece per file (see below) |

### Client modules (`HFF/`)

| Module | What it does |
| --- | --- |
| `Shared` | Config, remotes, shared state and signals |
| `Signal`, `Util` | Tiny event helper; math helpers (closest point, camera yaw, noise) |
| `Input` | Keyboard/mouse, gamepad and touch input; current input mode |
| `Drives` | Creates and poses the AlignOrientation joint drives |
| `Rig` | Builds and destroys the client-side forces/drives for a character |
| `Controller` | Per-frame step: balance, walking, jumping, arms |
| `LegIK` | Two-bone leg IK with foot planting and steps |
| `Knockdown` | Knockdowns, ragdoll toggle, stagger/teeter balance |
| `Reactions` | Euphoria reactions (flail, brace, writhe, push-up) |
| `Grab` | Hand contact detection and grip requests |
| `Camera` | Smoothed camera follow and mouse lock |

### HUD modules (`UI/`)

| Module | What it does |
| --- | --- |
| `UIController` | Creates the `HFFHud` ScreenGui and mounts everything |
| `Theme`, `Strings`, `Components` | Colors/fonts, Spanish/English text, reusable UI builders |
| `Responsive` | Scales the HUD to the screen size (UIScale) |
| `StatusBadge` | Top pill: Stumbling / Knocked down / Getting up |
| `ControlHints` | Bottom-left key hints for keyboard or gamepad (H hides them) |
| `TouchControls` | Phone/tablet L, R and Ragdoll buttons, sized to the screen |
| `SettingsMenu` | Gear button + menu (M / Select): mouse lock, Euphoria, Leg IK, hints |

## Install

1. Install the Rojo command-line tool (the Studio plugin alone is not enough), e.g. the "Rojo" VS Code
   extension, or `rojo.exe` from https://github.com/rojo-rbx/rojo/releases.
2. In this folder run `rojo serve` (it uses port 34872 from `default.project.json`).
3. In Studio: Plugins > Rojo > Connect (localhost, 34872).
4. Home > Game Settings > Avatar > Avatar type **R15**.

## Test

1. Press **Play** (F5). You spawn standing and wobbly next to the playground.
2. Controls:
   - **WASD** walk (camera-relative), **Space** jump
   - **Hold left mouse** reach with the left arm, **hold right mouse** with the right arm. Arms point
     where the camera looks; a hand that touches something grips it until you let go.
   - The camera is the normal Roblox camera (right-drag or shift lock to turn it); arms reach where it looks.
   - **Gamepad**: left stick moves, right stick turns the camera, A jumps, L2/L1 left arm, R2/R1 right arm.
   - **Phone/tablet**: Roblox thumbstick and jump button, plus round **L** and **R** hold buttons for the arms (drag the screen to aim).
   - **R** (gamepad Y, phone Ragdoll button) toggles ragdoll.
   - **M** (gamepad Select, or the gear top right) opens settings. **H** hides the control hints. **Alt** frees the mouse.
3. Things to try:
   - Walk into a crate, hold both mouse buttons, look at it, then walk: you carry it.
   - Look up at the ledge on the grey wall, hold both buttons to grab it, then look down
     (arms pull) and jump/walk forward to climb.
   - Jump off the top of the wall: the landing knocks you limp for 2 s, then you get up.
4. Multiplayer: Test tab > Clients and Servers > 2 players > Start. Players can grab each other.

## How it works (defaults chosen)

- **Ragdoll body**: all R15 Motor6Ds become BallSocketConstraints with limits, except Root, Waist,
  wrists and ankles, which stay rigid (one solid torso, like HFF). Humanoid is put in the Physics
  state so it never walks or animates the body.
- **Balance**: a soft AlignOrientation on the HumanoidRootPart keeps the torso upright and turns it
  to face movement (or the camera while reaching). It is not rigid, so hits make you wobble.
- **Standing**: a spring force holds the torso at hip height above the ground (raycast), so legs can
  stay loose. Legs swing in a procedural stride driven by AlignOrientations on the hips and knees.
- **Walking**: a VectorForce chases the target velocity with capped acceleration, so you accelerate
  and stop with a bit of slide. Reduced control in the air or while hanging.
- **Grabbing**: the client detects hand contact and asks the server; the server validates distance
  and creates a BallSocketConstraint between hand and object, so every player sees the grip. Loose
  props become owned by the grabber so carrying has no lag. Grips break when stretched.
- **Knockdown**: a sudden velocity change (hard landing, getting hit) or staying tipped over too
  long turns all control off for `KnockdownTime`, then balance ramps back in. Other server scripts
  can knock someone down with `ReplicatedStorage.HFFRemotes.ServerKnockdown:Fire(player, seconds)`.
- **Limb colliders**: the Humanoid forces arm/leg collisions off, so each limb has an invisible welded `HFFCollider` part that collides instead.
- **Network ownership** of the body stays on the owning client for responsiveness.
- Set `Config.Debug = true` to print grounded/height/force in the client output once a second.
- Parts with the attribute `HFFNoGrab = true` cannot be grabbed.

## Tuning tips (all in HFFMovementConfig)

- Too stiff / not wobbly enough: lower `BalanceResponsiveness` or `BalanceMaxTorque`.
- Falls over constantly: raise `BalanceMaxTorque`, `FallTiltAngle`, or `ImpactKnockdownSpeed`.
- Floating above the ground / feet sinking: adjust `StandHeightScale` (e.g. 0.95 or 1.05).
- Bouncy standing: raise `HoverDamping`; sluggish: raise `HoverStiffness`.
- Climbing too hard: raise `ArmMaxTorque`.
- Leg swing going the wrong way on a custom rig: flip the sign of `StrideAngle`.

## Known rough edges

- Player-on-player grabs connect two client-owned bodies, so they can jitter under latency.
- A grip appears after one round trip to the server (instant in Studio, ping-delayed live).
