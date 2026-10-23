# Sniper Game (working title)

A fast, sniper-only Roblox FPS with Krunker-style quickscoping and movement that builds momentum.
The full design is in [docs/GAME_PROMPT.md](docs/GAME_PROMPT.md).

**Status: Phases 1–7 are written but haven't been played yet.** That covers movement, all 5 snipers with
attachments, sounds and effects, the knife, kill feed, scoreboard and death cam, the Free-For-All match on Cinder
Terraces, saving, coins, the shop, the settings menu, the main menu, inspect animations, and phone and controller
support. Next step is testing in Roblox Studio. Expect a few bugs on
the first run.

The game is **arcade-style on purpose**: your shot always goes exactly where the crosshair is, with no scope sway.

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
8. **Play:** press **Play** (F5). The game builds the map itself and opens on the main menu; press **PLAY** to
   spawn. The first match starts after a 15-second warm-up.

Leave VS Code and Rojo running while you work. Every file you save in VS Code updates in Studio right away.

**Saving in Studio:** progress only saves once the place is published (File → Publish to Roblox) and **Game Settings →
Security → Enable Studio Access to API Services** is on. Without that, everything still works but resets when you
stop playing (you'll see a warning in Output).

**To test on the Test Range** (dummies, labeled movement areas): open `src/shared/Config/MatchConfig.luau` and set
`FirstMap = "TestRange"`. You can also vote for it with F2 during warm-up.

> **No Rojo?** You can make each script in Studio by hand and paste the code in. `src/shared` becomes a Folder
> named `Shared` in ReplicatedStorage, `src/server` becomes a Folder named `Server` in ServerScriptService,
> `src/client` becomes a Folder named `Client` in StarterPlayer → StarterPlayerScripts, and the files in
> `src/character` go straight into StarterPlayer → StarterCharacterScripts. `.server.luau` files are Scripts,
> `.client.luau` files are LocalScripts, and everything else is a ModuleScript (named without `.luau`). Also turn
> off StarterPlayer → **EnableMouseLockOption** and set Lighting → **Technology** to **Future**.

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
| Sniper / knife | 1 / 3, or Q to swap | Y to swap |
| Knife slash / lunge | Left click / right click | Right trigger / left trigger |
| Scoreboard (hold) | Tab | View / Back |
| Inspect your weapon | F | D-pad up |
| Menu (loadout, shop, settings, stats) | M | D-pad down (B to close, D-pad to navigate) |
| Vote for a map | F1 / F2 (or click, on the results screen) | |
| Debug info | F3 | |

Scope and sprint can be switched to toggle (click once) instead of hold in **M → Settings → Controls**.

**Phones and tablets:** move with the on-screen thumbstick (push it all the way forward to sprint) and drag
anywhere else to look. Buttons on the right: FIRE (knife: slash), SCOPE (taps on and off; knife: lunge), JUMP,
SLIDE (hold), R (reload), SWAP and F (inspect); ☰ opens the menu. Button size is in **Settings → Controls**.

**Controllers** also auto-sprint with the stick pushed fully forward (can be turned off in Settings).

## The match

- **Free-For-All:** first to 25 kills, or the most kills after 8 minutes. Then a results screen with a top-3
  podium and everyone's stats, then a 15-second warm-up where everyone votes for the next map.
- **Spawns** are picked away from enemies and out of their sight. You get 1.5 s of spawn protection (the bubble),
  which ends early the moment you attack.
- **Falling** off the map (into the sea on Cinder Terraces) counts as a death.

## Cinder Terraces

A cliffside resort town at golden hour above a teal sea. Raised spawn terraces at the east and west ends, with
sloped streets running down into three lanes:

- **North:** rooftops 15 studs apart with long sightlines. You need about 30 speed to clear a gap. There's a
  narrow beam across the middle, and stairs up at both ends.
- **Middle:** a plaza around a clock tower. The tower balcony is a strong spot but open from every side; climb the
  ladders or drop through the rail gaps. Market stalls have awnings you can stand on.
- **South:** alleys between houses, with 9-stud gaps for wall-kick chains, stairs up onto the roofs, and a
  promenade along the cliff edge.
- **4 Slingshots** (orange stripes): two in the north street launch you onto the rooftops, and two at the south
  edge of the plaza launch you onto the houses.

## How the movement works

- **Sprint:** hold Shift while moving forward to go from 18 to 25 studs/s. It only works forward.
- **Bhop:** jump again right as you land (within 0.1 s) to keep your speed and get +4%. While in the air, hold A or
  D and turn your mouse the same way to gain speed (air strafing).
- **Slide:** press C while moving fast. You get a speed boost (once every 0.8 s), and downhill slopes speed you up.
  Jumping out of a slide keeps all its speed. Sprint → slide → jump is the fastest way to start a chain.
- **Wall kick:** press jump in the air next to a wall to bounce off it. You get 2 before you have to land.
- **Slingshot:** slide into a ramp with an orange stripe to launch up.
- **Flow:** the ring of dots around your crosshair. Perfect hops, slide-jumps, wall kicks and air kills fill it.
  Each tier raises your top speed (30 → 36 → 42) and adds speed lines at the screen edges. Filling it completely
  starts **Overflow**: top speed 48 for 4 seconds, with the ring glowing. Standing around drains it, and getting
  hit takes some away.

## How the sniper works

- **VANTA:** headshots always kill, body shots kill (100 damage), arm and leg shots do 75. 5 shots, 0.9 s bolt
  between shots, 2 s reload. An empty mag reloads by itself.
- **Scoping:** hold right click. The scope comes up in 0.14 s. Shots are wildly inaccurate unscoped and get more
  accurate as the scope comes up, so a well-timed **quickscope** is accurate.
- **After each shot** you unscope while the bolt cycles. Keep holding right click to scope back in automatically.
- **Scoped movement:** walking is slower while scoped, but slides and bhops keep their speed.
- **Kill tags:** HEADSHOT, NOSCOPE (barely scoped), QUICKSCOPE (within 0.25 s of the scope finishing), AIRSHOT,
  FLOW KILL (during Overflow), LONGSHOT (200+ studs), WALLBANG (through a wall), SHUTDOWN (ending a 5+ kill
  streak), REVENGE (killing whoever last killed you) and FIRST BLOOD (the match's first kill). Quick kills chain
  into DOUBLE KILL, TRIPLE KILL and RAMPAGE.
- **Spawn protection:** shots at a player still in their spawn bubble show no hitmarker, since they can't be hurt.
- **Health** comes back 5 seconds after you last took damage. You respawn 4 seconds after dying.
- **Hit registration:** your game checks the hit instantly (the hitmarker shows right away), then the server
  re-checks it, rewinding the target to where you saw them. Kills only count once the server agrees.

## The snipers

All five share the same controls; buy them with coins in **M → Shop**, then equip in **M → Loadout**.

| Sniper | Price | What it's about |
| --- | --- | --- |
| VANTA | free | The all-rounder: one shot to the body or head, 0.9 s bolt, 5 rounds |
| NEEDLE | 1,500 | Fastest scope (0.1 s) and bolt, moves 6% faster; body shots do 70 |
| HARPOON | 3,000 | Any hit kills, and shots go through one thin wall (half damage); slow and heavy |
| TWINBOLT | 4,500 | Two quick shots (60 each, so two body shots kill), then reload |
| PULSE | 6,000 | Semi-auto: keep firing without leaving the scope; 55 body, wide hip-fire |

**Attachments** unlock by getting kills with that sniper (10 to 200 kills). Each has a trade-off:

- **Scope:** Standard, Long scope (more zoom), Red dot (2x, open sight, much faster)
- **Barrel:** Standard, Muzzle brake (half the kick), Long barrel (tighter hip-fire), Suppressor (no tracer for enemies, quieter)
- **Stock:** Standard, Light (faster scope, more kick), Heavy (less kick, slightly slower)
- **Bolt:** Standard, Match (+1 round, slower bolt), Greased (faster bolt, −1 round)
- **Mag:** Standard, Quick (faster reload), Extended (+2 rounds, slower reload)

Hovering an attachment in the Loadout shows how it changes the stat bars. Loadout changes apply on your next spawn.

## Coins

Kills during a match pay **25 coins**, plus 15 for a headshot, 20 for a knife lunge, 15 for a SHUTDOWN, and 10
each for a longshot, WALLBANG, REVENGE and FIRST BLOOD. Winning pays 150, and 2nd or 3rd place pays 75. Only tags
the server checks itself pay, so a hacked game can't fake them. Warm-up kills and Test Range dummies don't pay or
count toward the match (set `DummyKillsCount = true` in `MatchConfig.luau` to test the economy alone). Matches
only start once someone has pressed PLAY.

## Settings (M → Settings)

- **Controls:** mouse sensitivity, scoped sensitivity, toggle scope, toggle sprint
- **Video:** field of view, graphics quality (Low turns off shadows and most effects), camera motion, weapon bob,
  speed lines, FPS and ping counter
- **Crosshair:** style (cross, dot, cross + dot, circle), color, size, gap, thickness, outline, Flow ring
- **Audio:** master, effects, hit sounds, menus

Settings save to your profile, so they follow you between servers.

## Inspecting (F)

Each weapon shows off differently: VANTA does a barrel roll and racks the bolt, NEEDLE twirls twice, HARPOON
spins and hops, TWINBOLT flips end over end, PULSE twirls and tosses, and the knife spins three times in the air.
The accent parts glow during the spin. Scoping, firing, reloading or switching cancels it instantly.

## How the knife works

- Press **3** or **Q**. You move 15% faster with it out, Flow drains half as fast, and slide boosts come back
  sooner. Swapping takes 0.2 s.
- **Slash** (left click): 50 damage, short reach, every 0.35 s.
- **Lunge** (right click): dash 10 studs forward and hit the first enemy you reach for 100 damage (a **SLICE**).
  1.2 s cooldown.

## After you die

The **death cam** flies to just behind whoever killed you, looking back at where you fell. It shows their name,
health, weapon, the distance and the kill tags.

---

## Test checklist

Work through these in Studio and tell me anything that's off. All the numbers are in `src/shared/Config/`
(MovementConfig, WeaponConfig, MatchConfig, SoundConfig). Change one, save, and press Play again.

**Movement** (Test Range is easiest)
- [ ] Walking and jumping feel snappy, not floaty. Sprint works only forward, and the view widens a little.
- [ ] Shift does NOT turn on shift-lock. Holding Space does NOT auto-hop.
- [ ] Perfect hops and air strafing build speed (press F3 to see the number).
- [ ] Slides boost you, go faster downhill, and slide-jumps keep the speed.
- [ ] Wall kicks work (2 max), Slingshots launch you onto the platform, and you never get stuck on edges.
- [ ] The Flow ring fills, changes color, shows speed lines, and glows in Overflow.
- [ ] It feels the same with the frame rate capped at 60 and at 240 (Esc → Settings → Maximum Frame Rate).

**Sniper and knife** (Test Range has dummies behind the spawn)
- [ ] Hip-fire spread is huge and the crosshair matches; scoped shots hit dead center, even at 280 studs.
- [ ] Quickscopes, noscopes and mid-air kills show the right tags.
- [ ] Both strafing dummies can be hit; the dummy behind cover can NOT be hit from the spawn side.
- [ ] Firing unscopes you and the bolt moves; ammo counts down and reloads by itself when empty.
- [ ] The scoped crosshair stays perfectly still. Scoped mouse movement doesn't feel 4× faster.
- [ ] Q swaps to the knife and back. Slash and lunge both work on a dummy.
- [ ] Every action has a sound, and shots leave sparks or dust and a fading bullet hole.

**Match and map** (Cinder Terraces)
- [ ] Warm-up counts down, F1/F2 votes update the counts, and the match starts with a "MATCH START" banner.
- [ ] The timer counts down and the leader updates. Reaching 25 kills (set `KillTarget` lower to test) ends the
      match and shows the results screen; you can click a map to vote there.
- [ ] Spawns put you away from other players, with a short protection bubble.
- [ ] Rooftop gaps need momentum, the tower ladders and balcony work, and all 4 Slingshots land you on a roof.
- [ ] Jumping over the south railing into the sea kills you and shows "fell" in the kill feed.
- [ ] No red errors in the Output window (View → Output), and no "[AntiCheat] ... pulled back" during normal play.

**Main menu, inspect, touch and controller**
- [ ] Joining shows the main menu with the camera circling the map and your sniper turning on the right. Nobody can
      shoot you there; PLAY spawns you. The LOADOUT/SHOP/SETTINGS/STATS buttons open the menu.
- [ ] F plays the inspect for each sniper and the knife; scoping or firing cancels it at once.
- [ ] Studio's device emulator (Test tab → Device) on a phone shows the touch buttons, and every button works.
- [ ] With a controller: D-pad down opens the menu, the D-pad moves between buttons, A presses, B closes.

**Menu, shop and saving** (M)
- [ ] The menu frees the mouse; clicking in it never fires the gun, and right-click doesn't scope.
- [ ] Every setting changes something you can see or hear right away, and they're still set after rejoining (needs
      saving turned on, see setup).
- [ ] Buying a sniper takes the coins; equipping it and respawning gives you that sniper with its own colors.
- [ ] Locked attachments say how many kills they need; equipped ones apply on the next spawn.
- [ ] Each sniper behaves differently: NEEDLE's fast bolt, HARPOON shooting through the thin wall on the Test Range,
      TWINBOLT's two quick shots, PULSE staying scoped while firing.
- [ ] Coins pop up on kills during a match, and the totals survive a rejoin.

**With 2 players** (Test tab → Clients: 2 → Start)
- [ ] You see the other player's gun or knife in their hands.
- [ ] Kills show in everyone's kill feed, Tab shows the scoreboard, and dying shows the death cam.
- [ ] Shots still register with fake lag (File → Studio Settings → Network → Incoming Replication Lag = 0.15).

### Known limitations

- Sounds are placeholders built from Roblox's built-in sounds. Swap in real ones in
  `src/shared/Config/SoundConfig.luau` (instructions at the top of that file).
- Other players see default Roblox animations with the arms posed to hold the weapon. Real animations need to be
  made in Roblox's animation editor and uploaded.
- Crouching and sliding lower the camera but not your hitbox.
- The death cam shows the killer live rather than a true replay.
- Kill tags like AIRSHOT and FLOW KILL trust what the shooter's game reports, so they only appear in banners and
  stats; coin bonuses only use tags the server checks itself.
- All five snipers share one model, told apart by color. Unique models come later.
- Touch buttons are in fixed positions; dragging them around is a later addition.
- The game is called "SNIPER GAME" on the main menu until you pick a name (`src/shared/Config/GameConfig.luau`).

---

## Project layout

```
default.project.json             Rojo project: maps these folders into Studio
docs/GAME_PROMPT.md              the full design brief
src/shared/                      → ReplicatedStorage.Shared (used by client and server)
  Config/MovementConfig.luau     every movement number
  Config/WeaponConfig.luau       every weapon and combat number
  Config/MatchConfig.luau        match rules, coin rewards and map rotation
  Config/SettingsConfig.luau     every player setting with its default and range
  Config/GameConfig.luau         the game's name and tagline
  Config/SoundConfig.luau        every sound (placeholders to swap)
  Combat/Hitboxes.luau           which body parts are head, body or limb
  Combat/KillTags.luau           HEADSHOT, NOSCOPE, QUICKSCOPE and other kill tags
  Combat/WeaponStats.luau        a sniper's final numbers with its attachments
  Combat/Ballistics.luau         shot casting, including through thin walls
  Net.luau                       the RemoteEvents client and server talk through
  Util/Spring.luau               smooth spring math for the camera and gun
  Util/Signal.luau               simple events between scripts
src/server/                      → ServerScriptService.Server
  Main.server.luau               starts every service
  Maps/CinderTerraces.luau       the main map
  Maps/TestRange.luau            gray test map with labeled areas and a shooting range
  Maps/MapKit.luau               building blocks for maps (ramps, stairs, buildings, Slingshots...)
  Services/MatchService          warm-up, vote, match, results loop, end-of-match coins
  Services/DataService           saving and loading profiles (with locking and retries)
  Services/ShopService           buying snipers and choosing loadouts
  Services/PlayService           spawning after PLAY, and respawning after deaths
  Services/MapService            loads maps, kills anyone who falls off
  Services/SpawnService          safe spawn picking and spawn protection
  Services/CombatService         checks every shot and knife hit, applies damage, health regen
  Services/LagCompensation       remembers where hitboxes were for the last second
  Services/StatsService          kills, deaths, headshots, streaks and ping per player
  Services/AntiCheatService      server speed check
  Services/WorldWeaponService    the gun and knife other players see in your hands
  Services/LightingService       the game's lighting look, per map
  Services/TestDummyService      shooting-range dummies (Test Range only)
  Services/MatchState            shared match flags
src/character/                   → StarterCharacterScripts
  Health.server.luau             turns off Roblox's default health regen
src/client/                      → StarterPlayerScripts.Client
  Main.client.luau               hides default Roblox HUD pieces, starts the controllers
  Controllers/MovementController     sprint, bhop, slide, wall kick, Slingshot, Flow
  Controllers/WeaponController       scoping, firing modes, bolt, reload, recoil, weapon switching
  Controllers/SettingsController     the player's settings, saved to their profile
  Controllers/ProfileController      coins, owned snipers, loadouts and stats from the server
  Controllers/MenuController         the M menu: loadout, shop, settings, stats
  Controllers/GraphicsController     applies the graphics quality setting
  Controllers/MainMenuController     title screen, 3D sniper showcase, PLAY
  Controllers/TouchController        on-screen buttons for phones and tablets
  Controllers/KnifeController        knife slash and lunge
  Controllers/CameraController       first person, camera dip/tilt, FOV, scope zoom, fire kick
  Controllers/SoundController        plays every sound
  Controllers/EffectsController      impacts, bullet holes, other players' tracers
  Controllers/CharacterPoseController  arm poses for other players
  Controllers/DeathCamController     the camera and panel after you die
  Controllers/WeaponHud              crosshair, scope overlay, hitmarkers, kill banner, ammo, health
  Controllers/FlowHud                Flow ring and speed lines
  Controllers/MatchHud               timer, banners, map vote, results screen
  Controllers/KillFeedHud            kill feed
  Controllers/ScoreboardHud          Tab scoreboard
  Controllers/DebugHud               F3 debug info
  Weapon/Viewmodel.luau              first-person sniper, knife and arms
  Weapon/Tracers.luau                bullet tracers
  Weapon/Inspect.luau                the inspect animation
  UI/Widgets.luau                    buttons, sliders, toggles and stat bars for menus
stylua.toml                      code formatting settings
```

## Next up: Phase 8

Robux skins (with special inspects for Legendary ones), daily rewards, quests, codes, leaderboards, a season pass
and badges.
