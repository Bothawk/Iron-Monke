# Game design prompt

This is the full design brief. Paste it into an AI coding assistant to keep building the game, one phase at a time.
Phases 1-4 are already written in this project, so tell the assistant to start from Phase 5 and read the existing code first.

Changes from the first version:
- Sprint added: hold Left Shift while moving forward. Crouch/slide is C.
- Steady scope is "hold Shift while scoped" (you can't sprint while scoped, so the key is free).
- FOV is described in Roblox terms (vertical).
- Air strafing runs at a fixed rate so the frame rate doesn't change speed gain.

---

```
You are a senior Roblox game designer and expert Luau engineer. We're building a fast, competitive sniper-only FPS on Roblox together. Read this whole brief before writing any code. Build in the PHASES at the bottom, one at a time, and don't move to the next phase until the current one passes its checklist. When something isn't specified, pick what makes the game feel faster, cleaner and more satisfying, and tell me what you chose.

=====================================================
1. THE VISION
=====================================================
Game name: [GAME NAME] (placeholder).
In one sentence: Krunker-speed sniping plus movement that builds momentum, on Roblox, with the cleanest feel on the platform.
The 3 pillars (every feature must support at least one):
  1. MOVEMENT IS SKILL: speed is earned by chaining jumps, slides and wall kicks, never given for free.
  2. EVERY SHOT MATTERS: snipers only, one-shot headshots, quick scoping, very precise hit registration.
  3. IT FEELS EXPENSIVE: smooth camera, crisp sounds, clean UI, no jank.
NOT allowed: default Roblox UI fonts, unmodified default character movement, pay-to-win, cluttered HUDs, deprecated APIs, laggy or delayed hit registration.

=====================================================
2. MOVEMENT SYSTEM (built in phase 1, see src/client/Controllers/MovementController.luau)
=====================================================
Custom movement controller on the client. It computes velocity every frame (RunService.PreSimulation) and drives the Humanoid with it, so the default WalkSpeed/JumpPower feel never applies. All values are in src/shared/Config/MovementConfig.luau.

Base values:
  - Walk speed (sniper equipped): 18 studs/s
  - Sprint (hold Left Shift, forward only): 25 studs/s. Can't sprint while scoped, crouching or sliding
  - Knife equipped: all ground speeds × 1.15
  - Scoped-in speed: 10 studs/s
  - Ground acceleration: reaches max speed in about 0.12 s; ground friction stops you in about 0.1 s
  - Jump height: about 7.5 studs. Gravity 230 (Roblox default 196.2) so jumps feel snappy
  - Coyote time: 0.1 s. Jump buffer: 0.12 s

BHOP / AIR STRAFING (Source-engine style):
  - No friction in the air. Air acceleration works like Source: strafing (A/D) while turning the mouse adds speed. It runs at a fixed 60 Hz step so frame rate doesn't change speed gain.
  - Jumping within 0.1 s of landing skips ground friction (perfect hop), keeps speed, and adds +4%.
  - Every hop needs a fresh jump press (no hold-to-hop).

SLIDING:
  - Crouch (C) while moving faster than 16 studs/s to slide. +6 studs/s boost on entry (0.8 s cooldown), then low friction.
  - Downhill slopes add speed (scaled by slope angle). Uphill drains speed faster.
  - Slide-jump keeps 100% of the slide's speed.
  - Camera drops 1.5 studs smoothly, tilts 3° toward the strafe direction, and FOV rises slightly.

THE UNIQUE TWIST: "FLOW"
Momentum is shown and rewarded with a Flow meter (0-100), drawn as a thin arc around the crosshair (phase 1 uses a temporary bar).
  - Flow goes up from: perfect hops (+8), slide-jumps (+12), wall kicks (+15), kills while airborne (+25).
  - Flow goes down: when you stand on the ground for more than 0.4 s without sliding, it drains at 40/s. Getting hit takes away 30 (and ends Overflow).
  - Flow tiers:
      Tier 0 (0-32): speed cap 30.
      Tier 1 (33-65): speed cap 36. Subtle speed lines at the screen edges.
      Tier 2 (66-99): speed cap 42. FOV +4, slightly brighter crosshair, soft wind sound.
      Tier 3 (100, "OVERFLOW"): speed cap 48 for 4 s, then Flow drops to 70. Rings around the crosshair glow, footsteps get a unique sound, and a kill during Overflow is a "Flow Kill" (bonus currency + a special kill sound).
  - WALL KICK: jumping in the air next to a wall bounces you off it. Max 2 before you land again.
  - SLINGSHOT: slide into a ramp tagged "Slingshot" (with an accent stripe) to launch upward. The real map has 4 of these.

Anti-exploit (built in phase 1): the server samples each player's position every 0.25 s and pulls them back if they repeatedly move faster than the highest speed cap plus a tolerance.

=====================================================
3. SNIPERS (Krunker-style)
=====================================================
HIT REGISTRATION (must be perfect):
  - Hitscan with workspace:Raycast using RaycastParams. The client raycasts immediately for instant feedback (hitmarker, sound).
  - The client sends the shot to the server: origin, direction, timestamp, claimed hit part.
  - The server does LAG COMPENSATION: it stores each character's hitbox positions 20 times a second for the last 1 s, rewinds to the shooter's timestamp (capped at 250 ms), re-checks the shot, and only applies damage if it's valid.
  - The server checks: fire-rate cooldown, ammo, that the origin is near the shooter's head (within 4 studs), and line of sight.
  - Damage only happens on the server. The client never applies damage.

SCOPING (fast like Krunker):
  - ADS time: 0.10-0.20 s depending on the sniper and attachments.
  - Hipfire: large random spread (about 6°) with the crosshair visibly spread open.
  - Scoped: 0 spread once ADS is 100% complete. During the scope-in animation, spread blends from hipfire to 0, so quickscopes work and reward timing.
  - Scope overlay: a clean black vignette with a thin crosshair reticle (no fake lens dirt), plus a tiny bit of sway that settles in 0.3 s. Holding Shift while scoped steadies it for 2 s.
  - ADS sensitivity multiplier as a setting (default 0.7).
  - Rechamber (bolt) after every shot. Firing un-scopes automatically, Krunker style, with a satisfying bolt animation and sound.
  - Getting a kill calls MovementController.OnKill() and taking damage calls MovementController.OnDamaged(), so Flow reacts to combat.

DAMAGE MODEL (100 HP players):
  - Head: always a kill.
  - Body: depends on the sniper.
  - Limbs: body damage × 0.75.
  - No damage drop-off with distance, except where noted.

THE SNIPERS (unlocked with in-game currency):
  1. "VANTA" (starter, free): ADS 0.14 s, body 100 (one-shot body), bolt 0.9 s, mag 5, reload 2.0 s. The well-rounded baseline.
  2. "NEEDLE" (1,500 coins): ADS 0.10 s, body 70, bolt 0.6 s, mag 6, move speed +6%. The quickscoper's pick.
  3. "HARPOON" (3,000 coins): ADS 0.20 s, body 100, limbs 100, shots go through 1 thin wall (penetrable surfaces only, 50% damage after), bolt 1.2 s, mag 4, move speed -8%.
  4. "TWINBOLT" (4,500 coins): two shots before rechambering (0.25 s between them), body 60, head 100, ADS 0.15 s, mag 2 (it's reloaded after each pair), reload 1.6 s.
  5. "PULSE" (6,000 coins): semi-auto, body 55, head 110, fire interval 0.35 s, ADS 0.16 s, mag 8, reload 2.2 s. Hipfire spread is large.
  Every number goes in a single WeaponConfig module so I can rebalance without touching the code.

ATTACHMENTS (unlocked by kills with that sniper, NOT bought with Robux). Each slot has trade-offs; no attachment is strictly better than another:
  - SCOPE: 4x (default), 6x (more zoom, +0.02 s ADS), Red Dot (2x, -0.03 s ADS, wider view)
  - BARREL: Suppressor (kills don't show on the minimap, quieter shot, -5% bolt speed), Muzzle Brake (less camera kick, louder), Long Barrel (+0.02 s ADS, less sway)
  - STOCK: Light Stock (-0.02 s ADS, more sway), Heavy Stock (less sway, -4% move speed)
  - BOLT: Greased Bolt (-15% bolt time, -1 mag), Match Bolt (+1 mag, +10% bolt time)
  - MAG: Quick Mag (-25% reload), Extended Mag (+2 mag, +15% reload)
  Unlock requirements: 10/25/50/100/200 kills with that sniper.

=====================================================
4. KNIFE
=====================================================
  - Press 3 or Q to switch (0.2 s). With the knife, ground speeds are × 1.15 (walk about 21, sprint about 29), Flow drains 50% slower, and slide-boost cooldown is 0.6 s.
  - Left click: quick slash (0.35 s, 50 damage, 5-stud range). Right click: lunge (dash forward 10 studs, 100 damage, 1.2 s cooldown). A lunge kill is a "Slice" (unique sound + kill banner).
  - Knife hits are checked on the server the same way as sniper shots.

=====================================================
5. FEEL / LOOK ("high FPS, smooth graphics")
=====================================================
  - Must be smooth: target 60 FPS on mid-range phones and 144+ on PC. Don't do any per-frame Instance creation; pool bullets, tracers, effects and sounds.
  - Viewmodel: the client renders the arms and sniper (a separate viewmodel parented to the camera), with:
      * Sway: follows mouse movement, smoothed with springs (src/shared/Util/Spring.luau: stiffness ~180, damping ~0.8)
      * Bob: tied to movement speed, turned off while scoped
      * Tilt during slides and air strafes
      * Recoil: snap back, return in 0.15 s
      * Inspect animation (F key)
  - Camera: FOV slider 70-100 (Roblox FieldOfView is vertical; default 80 ≈ 110 horizontal on 16:9). Small FOV kick when firing. Smooth landing dip based on fall speed.
  - Lighting: Future lighting, crisp clean look. No heavy bloom, no blur, slight color correction (+0.05 contrast, +0.1 saturation). Moderate SunRays.
  - Tracers: a thin bright line that fades in 0.08 s. Impact effects: small sparks plus a decal by surface type (metal/concrete/wood).
  - Graphics presets: Low (no shadows, fewer particles), Medium, High. Plus an FPS counter toggle and a ping display.

=====================================================
6. SOUND DESIGN (very important)
=====================================================
All sounds must be original or properly licensed audio uploaded to the game, with no ripped game sounds. Put sound IDs in a SoundConfig module.
  - HEADSHOT: a layered sound: a sharp high metallic "tink" + a deep short thump + a quick reverse-swoosh tail, about 0.3 s total. It should feel as satisfying as Rust's headshot sound but be clearly its own sound. Pitch rises slightly with each consecutive headshot in a streak (+3% per headshot, max +15%).
  - BODY HIT: a softer, duller thud with a little crunch.
  - KILL: a short low "boom" + a clean bell-like ring layered on top. Headshot kills play both the headshot sound and the kill sound.
  - FLOW KILL: the kill sound plus a whooshing echo.
  - SLICE (knife kill): a fast metallic ring.
  - Hitmarker: the X-shaped crosshair marker flashes white on body hits, red on headshots, and a thicker red X on kills.
  - Everything else: distinct footsteps by surface, slide scrape, wind that gets louder with speed, scope-in click, bolt rack, reload, and an in-air "whoosh" on wall kicks.
  - Volume sliders: master, effects, hit sounds, music, UI.

=====================================================
7. HUD (in-match, keep it simple)
=====================================================
Minimal and clean, using one consistent font (e.g. GothamSSm or a custom font) and a 2-color accent scheme.
  - Center: crosshair (customizable in settings: style, color, size, gap, outline), Flow arc, hitmarker.
  - Bottom left: HP bar (thin, fills smoothly with a tween) + number.
  - Bottom right: sniper name, ammo (current/mag), attachment icons.
  - Top right: killfeed (max 5 lines, shows the sniper icon, a headshot icon, and Flow/Slice icons).
  - Top center: match timer + your score/rank.
  - Kill banner: "+100 HEADSHOT" style banners in the lower middle, stacking up for streaks.
  - Tab: scoreboard (rank, name, K/D, headshot %, ping).
  - Death: killcam (3 s replay from the killer's view, using recorded positions), the killer's health and sniper, then respawn in 4 s.

=====================================================
8. MENUS
=====================================================
Built with clean layouts (UIListLayout/UIGridLayout), 0.2 s tweens on everything, hover sounds and scale-on-hover.
  - MAIN MENU: the player's character holding their equipped sniper in a 3D showcase (a ViewportFrame or a staged scene), slowly rotating. Buttons: PLAY, LOADOUT, SHOP, SKINS, PASS, SETTINGS, STATS. Coins and level at the top.
  - LOADOUT: pick a sniper, then attachments per slot, shown with a live 3D preview and stat bars that update to show what changes (green = better, red = worse).
  - SHOP (coins): buy snipers. Shows each sniper's stats, a preview, and the coin price.
  - SKINS (Robux only): sniper skins (see section 9).
  - SETTINGS: sensitivity, ADS sensitivity, FOV, crosshair editor, keybinds, graphics preset, FPS counter, volume sliders.
  - STATS: kills, deaths, K/D, headshot %, longest shot, best streak, Flow kills, time played.
  - Supports PC, mobile (with movable buttons for slide/jump/fire/scope and an auto-fire-on-scope option) and controller.

=====================================================
9. ECONOMY AND MONETIZATION (fair and Roblox-compliant)
=====================================================
COINS (earned only by playing):
  - Kill: 25. Headshot kill: +15. Flow kill: +15. Slice: +20. Win the match: +150. Top 3: +75.
  - Snipers and attachments are coins/kills only. Robux can never buy anything that affects gameplay.
SKINS (Robux only):
  - Sold through Developer Products. Ownership is saved in the DataStore, and purchases are processed with MarketplaceService.ProcessReceipt using receipt IDs so a purchase can never be granted twice or lost.
  - Rarities: Rare (~79 R$), Epic (~149 R$), Legendary (~299 R$, with an animated texture plus a custom inspect animation).
  - Sold directly, not through random paid crates. If random crates are ever added, show the odds and use PolicyService to respect regions where they're restricted.
  - Weekly rotating featured skins in the shop (a timer shows when it refreshes).

=====================================================
10. THINGS POPULAR ROBLOX GAMES HAVE (adds hooks)
=====================================================
  - Levels/XP with a level icon next to your name; prestige at level 50 that gives a special badge.
  - Daily login streak rewards (coins, with a bigger reward every 7th day).
  - Daily quests (3 a day, e.g. "Get 5 headshots", "Get 2 Flow kills") and weekly quests that give coins/XP.
  - A season pass with free and premium tracks (premium bought with Robux, cosmetics only: skins, kill banners, crosshair styles, titles).
  - A codes box in the menu (redeem codes from social media for coins/cosmetics, validated on the server, one use per player).
  - Global leaderboards (kills, headshots, longest shot) using OrderedDataStore.
  - Party system: invite friends and queue together.
  - Spectate mode when you join a match in progress.
  - Badges for milestones (first headshot, 100 kills, first Overflow, etc.).

=====================================================
11. THE MAP (one for now): "CINDER TERRACES"
=====================================================
Theme: a cliffside resort city at golden hour, with orange-pink sky, clean white stone, terracotta roofs, teal water far below. Clean and readable, not cluttered.
  - Size: about 500 × 350 studs. Max 12 players (Free-For-All).
  - Layout: 3 lanes.
      * North lane: long open rooftops (long sightlines, 150+ studs), connected by gaps you can only cross with momentum.
      * Middle: a tall clock tower in the center (strong position, but exposed from every side), surrounded by sloped streets that are perfect for slides.
      * South lane: tight alleys and stairs (close range, good for knife and quickscopes), with walls set up for wall-kick chains.
  - 4 Slingshot ramps (accent stripe) that launch you onto roofs or the tower.
  - Wall-kick spots: alleys set up with walls about 8-10 studs apart for chaining kicks.
  - At least 12 spawn points. Spawns are chosen based on distance from enemies and whether enemies can see them, so spawn kills are rare.
  - Out-of-bounds: falling into the sea respawns you (counts as a death).
  - Performance: use MeshParts for detail, keep the part count reasonable, turn on StreamingEnabled, and use CanCollide=false invisible collision boxes so players don't snag on decorative details.
  - It replaces the phase 1 test map (src/server/Services/TestMapBuilder.luau only builds when there's no "Map" folder in Workspace).

=====================================================
12. GAME MODE
=====================================================
FREE-FOR-ALL: first to 25 kills or 8 minutes. Then a results screen (top 3 shown on a podium with their skins, coins earned, XP bar animation), then a map vote (one map for now, but build the vote system so new maps can be added later), then the next match after 15 s.
Plan for later (build the structure to support these, but don't make them yet): Team Deathmatch, Ranked.

=====================================================
13. TECHNICAL ARCHITECTURE
=====================================================
  - The project uses Rojo (default.project.json). Code goes in .luau files, not edited directly in Studio.
  - Use Luau with --!strict wherever possible. No deprecated APIs: use task.wait/task.spawn, LinearVelocity/AlignOrientation instead of BodyMovers, and workspace:Raycast instead of Ray.new.
  - Folder structure:
      src/shared   → ReplicatedStorage.Shared (Config, Util, Types)
      src/server   → ServerScriptService.Server (Main.server.luau + Services/: MatchService, CombatService, DataService, ShopService, QuestService, AntiCheatService)
      src/client   → StarterPlayerScripts.Client (Main.client.luau + Controllers/: MovementController, CameraController, WeaponController, ViewmodelController, UIController, SoundController)
      Remotes are created by the server in ReplicatedStorage.Remotes, named clearly.
  - Data: ProfileStore (or ProfileService) with session locking, retries, and autosave every 60 s. Save the player's data when they leave and when the server shuts down (BindToClose).
  - Security:
      * Every RemoteEvent is checked on the server for argument types, rate limits, and whether the action is allowed.
      * Coins, XP, unlocks and ownership are changed ONLY on the server.
      * Never trust the client for damage, currency, speed or purchases.
  - Every number that might be tuned goes in a Config module, not hardcoded.
  - Add short, clear comments that explain WHY something is done, not what every line does.
  - Format with StyLua (stylua.toml is in the project).

=====================================================
14. BUILD PHASES (do one at a time, then stop and tell me how to test)
=====================================================
PHASE 1 (DONE): Movement (walk, sprint, jump, bhop, slide, wall kick, Flow meter, Slingshot) on a gray test map, plus the server speed check.
PHASE 2 (DONE): VANTA sniper with ADS, quickscope, hit registration with lag compensation, damage, death/respawn. Checklist: shots never hit through walls they shouldn't, headshots at 200+ studs register at 150 ms ping.
PHASE 3 (DONE): Feel pass (viewmodel, camera, tracers, impact effects, all sounds including the headshot/kill sounds).
PHASE 4 (DONE): HUD, killfeed, killcam, scoreboard. Knife.
PHASE 5: Free-For-All match system and the Cinder Terraces map.
PHASE 6: Data saving, coins, the other 4 snipers, the shop, attachments.
PHASE 7: Menus, settings, mobile and controller support.
PHASE 8: Robux skins (ProcessReceipt), daily rewards, quests, codes, leaderboards, season pass, badges.
PHASE 9: Polish and performance (profile with the MicroProfiler, fix anything over budget), exploit test (try speed hacking, firing too fast and fake hits, and confirm the server rejects them).

For every phase, give me:
  1. Complete code for every script (no "..." placeholders), with where each script goes.
  2. What I need to set up by hand in Studio (parts, attributes, asset IDs).
  3. A step-by-step test checklist.
  4. Known limitations and what you'd improve next.
```
