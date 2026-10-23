# Sniper Game (working title)

A fast, sniper-only Roblox FPS with Krunker-style quickscoping and movement that builds momentum.
The full design is in [docs/GAME_PROMPT.md](docs/GAME_PROMPT.md).

**Status: Phases 1–4 are written but haven't been played yet:** movement, the VANTA sniper, the feel pass (sounds,
effects, gun model) and the knife, kill feed, scoreboard and death cam. Next step is testing them in Roblox Studio.

---

## Setting up on your PC (one time, about 15 minutes)

You need a Windows PC or a Mac. Roblox Studio doesn't run on iPad.

1. **Install Roblox Studio:** go to [create.roblox.com](https://create.roblox.com), sign in, and download Studio.
2. **Install VS Code:** download it from [code.visualstudio.com](https://code.visualstudio.com). It's a free code
   editor.
3. **Download this project:** on this GitHub page, click the green **Code** button → **Download ZIP**, then unzip it.
4. **Install the Rojo extension:** in VS Code, click the Extensions icon on the left (four squares), search for
   **Rojo** (by evaera), and click Install.
5. **Open the project:** in VS Code, choose File → Open Folder and pick the unzipped folder (the one with
   `default.project.json` in it).
6. **Start Rojo:** press `Ctrl+Shift+P` (`Cmd+Shift+P` on a Mac), type **Rojo: Open menu**, and press Enter.
   - If it offers to install Rojo or the Roblox Studio plugin, say yes to both.
   - Click `default.project.json` to start the Rojo server.
7. **Connect Studio:** open Roblox Studio, create a new **Baseplate** place, open the **Plugins** tab, click
   **Rojo**, then **Connect**. All the scripts appear in Studio.
8. **Play:** press **Play** (F5). The test map builds itself when the game starts, replacing the template's
   baseplate.

Leave VS Code and Rojo running while you work. Every file you save in VS Code updates in Studio right away.

> **No Rojo?** You can make each script in Studio by hand and paste the code in. `src/shared` becomes a Folder
> named `Shared` in ReplicatedStorage, `src/server` becomes a Folder named `Server` in ServerScriptService, and
> `src/client` becomes a Folder named `Client` in StarterPlayer → StarterPlayerScripts. `.server.luau` files are
> Scripts, `.client.luau` files are LocalScripts, and everything else is a ModuleScript (named without `.luau`).
> Also turn off StarterPlayer → **EnableMouseLockOption**, or Shift turns on shift-lock instead of sprinting.

---

## Controls

| Action | Keyboard | Controller |
| --- | --- | --- |
| Move | WASD | Left stick |
| Sprint | Left Shift (hold, moving forward) | Click left stick |
| Jump / wall kick | Space | A |
| Crouch / slide | C | B |
| Shoot | Left click | Right trigger |
| Scope (hold) | Right click | Left trigger |
| Reload | R | X |
| Steady scope (hold, while scoped) | Left Shift | Click left stick |
| Sniper / knife | 1 / 3, or Q to swap | Y to swap |
| Knife slash / lunge | Left click / right click | Right trigger / left trigger |
| Scoreboard (hold) | Tab | View / Back |
| Debug info | F3 | |

Phone and tablet touch controls come in phase 7.

## How the movement works

- **Sprint:** hold Shift while moving forward to go from 18 to 25 studs/s. It only works forward, not sideways or
  backward.
- **Bhop:** jump again right as you land (within 0.1 s) to keep your speed and get +4%. While in the air, hold A or
  D and turn your mouse the same way to gain speed (air strafing).
- **Slide:** press C while moving fast. You get a speed boost (once every 0.8 s), and downhill slopes speed you up.
  Jumping out of a slide keeps all its speed. Sprint → slide → jump is the fastest way to start a chain.
- **Wall kick:** press jump in the air next to a wall to bounce off it. You get 2 before you have to land.
- **Slingshot:** slide into the ramp with the orange stripe to launch up.
- **Flow:** the ring of dots around your crosshair. Perfect hops, slide-jumps, wall kicks and air kills fill it,
  and each tier raises your top speed (30 → 36 → 42) and adds speed lines at the screen edges. Filling it
  completely starts **Overflow**: top speed 48 for 4 seconds, with the ring glowing. Standing around on the
  ground drains it, and getting hit takes some away.

## How the sniper works

- **VANTA:** headshots always kill, body shots kill (100 damage), arm and leg shots do 75. 5 shots, 0.9 s bolt
  between shots, 2 s reload. An empty mag reloads by itself.
- **Scoping:** hold right click. The scope comes up in 0.14 s. Shots are wildly inaccurate unscoped and get more
  accurate as the scope comes up, so a well-timed **quickscope** (click right as the scope finishes) is accurate.
- **After each shot** you unscope while the bolt cycles. Keep holding right click to scope back in automatically.
- **Scoped movement:** walking is slower while scoped, but slides and bhops keep their speed, so you can scope
  mid-air.
- **Scope sway:** the scoped crosshair drifts a little, most right after scoping in and while moving fast. Hold
  Shift to steady it for up to 2 seconds; hold too long and it gets shaky for a moment.
- **Kill tags:** kills can be tagged HEADSHOT, NOSCOPE (barely scoped), QUICKSCOPE (fired within 0.25 s of the
  scope finishing), AIRSHOT, FLOW KILL (during Overflow) and LONGSHOT (200+ studs). Quick kills chain into
  DOUBLE KILL, TRIPLE KILL and RAMPAGE.
- **Health** comes back 5 seconds after you last took damage. You respawn 4 seconds after dying.
- **Hit registration:** your game checks the hit instantly (hitmarker shows right away), then the server re-checks
  it, rewinding the target to where you saw them. Kills only count once the server agrees.

## How the knife works

- Press **3** or **Q**. You move 15% faster with it out, Flow drains half as fast, and slide boosts come back
  sooner. Swapping takes 0.2 s.
- **Slash** (left click): 50 damage, short reach, every 0.35 s.
- **Lunge** (right click): dash 10 studs forward and hit the first enemy you reach for 100 damage (a **SLICE**).
  1.2 s cooldown.

## After you die

The **death cam** flies to just behind whoever killed you, looking back at where you fell, and shows their name,
their health, the weapon, the distance and the kill tags. You respawn after 4 seconds.

## Phase 1 test checklist (movement)

Go through these in Studio and note anything that feels off:

- [ ] Walking feels snappy: you get to full speed quickly and stop quickly.
- [ ] Sprint works only while holding Shift and moving forward, and the view widens a little.
- [ ] Shift does NOT turn on shift-lock.
- [ ] Jumping feels snappy, not floaty.
- [ ] Holding Space does NOT auto-hop. Every hop needs a fresh press.
- [ ] Hopping right as you land keeps speed. The SPEED number on screen should climb.
- [ ] Air strafing (A/D + turning the mouse) gains speed.
- [ ] Sliding gives a boost, and the camera dips and tilts.
- [ ] Sliding down the 10°/20°/30° slopes gains speed, and steeper ones gain more.
- [ ] Slide-jump keeps your speed.
- [ ] Wall kicks work in the alley, and a third kick before landing doesn't work.
- [ ] The Slingshot launches you onto the landing platform.
- [ ] The Flow bar fills, changes color, and Overflow happens at 100.
- [ ] Speed caps hold: the speed never goes above the current tier's cap.
- [ ] You never get stuck on ramp edges or walls.
- [ ] No red errors in the Output window (View → Output).
- [ ] Normal play never prints "[AntiCheat] ... pulled back" in Output.
- [ ] It feels the same with the frame rate capped at 60 and at 240 (press Esc → Settings → Maximum Frame Rate).

## Phase 2 test checklist (sniper)

There's a shooting range behind the spawn with dummies at 50–280 studs, two that strafe (one at full Overflow
speed), and one behind a wall.

- [ ] Hip-fire spread is huge, and the crosshair lines spread to match.
- [ ] The scope comes up fast, zooms in, and shows a round black overlay with a crosshair.
- [ ] Quickscopes work: right click then left click right as the scope finishes hits where you aimed.
- [ ] Scoped shots hit exactly where the crosshair is, even at 280 studs.
- [ ] Headshots show a red hitmarker; body shots show a white one.
- [ ] One body shot or headshot kills a dummy and shows "ELIMINATED" or "HEADSHOT" with the distance. Arm or leg
      shots don't kill in one hit.
- [ ] Dummies come back 3 seconds after dying.
- [ ] Both strafing dummies can be hit when you aim right at them.
- [ ] The dummy behind cover can NOT be hit from the spawn side, even if you shoot the top edge of the wall.
- [ ] Firing unscopes you, the bolt handle moves back, and you can't fire again until it's done.
- [ ] Ammo counts down from 5, and an empty mag reloads by itself. R reloads early.
- [ ] Walking slows down while scoped, sprint turns off, and slide/bhop speed is kept.
- [ ] Scoped mouse movement feels the same on screen as unscoped (not 4× faster).

## Phase 3–4 test checklist (feel, knife, HUD)

- [ ] The sniper has arms holding it, and the bolt handle moves back after each shot.
- [ ] Every action has a sound: shot, bolt, reload, scope in, hits, headshots (pitch rises on a headshot streak),
      kills, jumps, slides, wall kicks, Slingshot, Overflow. Faster movement adds wind.
- [ ] Shots leave sparks on metal, dust on everything else, and a bullet hole that fades after ~6 s.
- [ ] Scope sway is visible but small; holding Shift steadies it.
- [ ] The Flow ring fills and changes color; speed lines appear at tier 1+; the ring glows in Overflow.
- [ ] Kill banners show tags (try a noscope, a quickscope and a mid-air kill on the dummies).
- [ ] Q swaps to the knife and back smoothly. Slash and lunge both hit the 50-stud dummy if you walk up to it.
- [ ] With 2 players: you see the other player's gun (or knife) in their hands, the kill feed shows kills for
      everyone, Tab shows the scoreboard, and dying shows the death cam.

To test against a real player and lag: in Studio, go to the **Test** tab, set **Clients** to 2, and click
**Start**. Studio's network settings (File → Studio Settings → Network → Incoming Replication Lag) can add fake
lag; try 0.15 to check shots still register.

All the numbers are in `src/shared/Config/MovementConfig.luau` and `src/shared/Config/WeaponConfig.luau`. Change
one, save, and press Play again.

### Known limitations (planned for later phases)

- Crouching and sliding lower the camera but not your hitbox yet.
- Sounds are placeholders built from Roblox's built-in sounds. Swap in real ones in
  `src/shared/Config/SoundConfig.luau` (instructions at the top of that file).
- Other players see default Roblox animations with the arms posed to hold the weapon. Real animations need to be
  made in Roblox's animation editor and uploaded.
- The death cam shows the killer live rather than a true replay.
- No touch controls yet (phase 7).

---

## Project layout

```
default.project.json          Rojo project: maps these folders into Studio
docs/GAME_PROMPT.md           the full design brief
src/shared/                   → ReplicatedStorage.Shared (used by client and server)
  Config/MovementConfig.luau  every movement number
  Config/WeaponConfig.luau    every weapon and combat number
  Config/SoundConfig.luau     every sound (placeholders to swap)
  Combat/Hitboxes.luau        which body parts are head, body or limb
  Combat/KillTags.luau        HEADSHOT, NOSCOPE, QUICKSCOPE and other kill tags
  Net.luau                    the RemoteEvents client and server talk through
  Util/Spring.luau            smooth spring math for the camera and gun
  Util/Signal.luau            simple events between scripts
src/server/                   → ServerScriptService.Server
  Main.server.luau            sets gravity, builds the test map, starts every service
  Services/AntiCheatService   server speed check
  Services/CombatService      checks every shot and knife hit, applies damage, health regen
  Services/LagCompensation    remembers where hitboxes were for the last second
  Services/LightingService    the game's lighting look
  Services/StatsService       kills, deaths, headshots, streaks and ping per player
  Services/TestDummyService   shooting-range dummies (test map only)
  Services/TestMapBuilder     builds the gray test map
  Services/WorldWeaponService the gun and knife other players see in your hands
src/character/                → StarterCharacterScripts
  Health.server.luau          turns off Roblox's default health regen
src/client/                   → StarterPlayerScripts.Client
  Main.client.luau            starts the controllers
  Controllers/MovementController  sprint, bhop, slide, wall kick, Slingshot, Flow
  Controllers/WeaponController    scoping, sway, firing, bolt, reload, recoil, weapon switching
  Controllers/KnifeController     knife slash and lunge
  Controllers/CameraController    first person, camera dip/tilt, FOV, scope zoom, fire kick
  Controllers/SoundController     plays every sound
  Controllers/EffectsController   impacts, bullet holes, other players' tracers
  Controllers/CharacterPoseController  arm poses for other players
  Controllers/DeathCamController  the camera and panel after you die
  Controllers/WeaponHud           crosshair, scope overlay, hitmarkers, kill banner, ammo, health
  Controllers/FlowHud             Flow ring and speed lines
  Controllers/KillFeedHud         kill feed
  Controllers/ScoreboardHud       Tab scoreboard
  Controllers/DebugHud            F3 debug info
  Weapon/Viewmodel.luau           first-person sniper, knife and arms
  Weapon/Tracers.luau             bullet tracers
stylua.toml                   code formatting settings
```

## Next up: Phase 5

The Free-For-All match (first to 25 kills or 8 minutes, results screen, next match) and the Cinder Terraces map.
