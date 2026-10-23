# Sniper Game (working title)

A fast, sniper-only Roblox FPS with Krunker-style quickscoping and movement that builds momentum.
The full design is in [docs/GAME_PROMPT.md](docs/GAME_PROMPT.md).

**Current status: Phase 1 (movement) is written but hasn't been played yet.** It needs testing in Roblox Studio.

---

## Setting up on your PC (one time, about 15 minutes)

You need Windows or a Mac. Roblox Studio doesn't run on iPad.

1. **Install Roblox Studio:** go to create.roblox.com, sign in, and click "Start Creating" / download Studio.
2. **Install VS Code:** download it from code.visualstudio.com. It's a free code editor.
3. **Get this project onto your PC:**
   - On GitHub, open the `bothawk/iron-monke` repo, switch the branch dropdown from `main` to `sniper-game`,
     then click **Code → Download ZIP**.
   - Unzip it.
4. **Install the Rojo extension in VS Code:** open VS Code, click the Extensions icon on the left (four squares),
   search for **Rojo** (by evaera), and click Install.
5. **Open the project:** in VS Code, choose File → Open Folder and pick the unzipped folder
   (the one with `default.project.json` in it).
6. **Start Rojo:** press `Ctrl+Shift+P`, type **Rojo: Open menu**, and press Enter.
   - If it offers to install Rojo or the Roblox Studio plugin, say yes to both.
   - Click `default.project.json` to start the Rojo server.
7. **Connect Studio:** open Roblox Studio, create a new **Baseplate** place, open the **Plugins** tab,
   click **Rojo**, then **Connect**. All the scripts appear in Studio.
8. **Play:** press **Play** (F5). The test map builds itself when the game starts.

Leave VS Code and Rojo running while you work. Any file saved in VS Code updates in Studio right away.

> No Rojo? You can make each script in Studio by hand and paste the code in. Match the folder layout below:
> `src/shared` → a Folder named `Shared` in ReplicatedStorage, `src/server` → a Folder named `Server` in
> ServerScriptService, `src/client` → a Folder named `Client` in StarterPlayer → StarterPlayerScripts.
> `.server.luau` files are Scripts, `.client.luau` files are LocalScripts, everything else is a ModuleScript.

---

## Controls (phase 1)

| Action | Keyboard | Controller |
| --- | --- | --- |
| Move | WASD | Left stick |
| Jump / wall kick | Space | A |
| Crouch / slide | Left Shift or C | B |

Phone and tablet touch controls come in phase 7.

## How the movement works

- **Bhop:** jump again right as you land (within 0.1 s) to keep your speed and get +4%. Hold A or D and turn
  your mouse the same way while in the air to gain speed (air strafing).
- **Slide:** crouch while moving fast. You get a boost (once every 0.8 s), and downhill slopes speed you up.
  Jumping out of a slide keeps all its speed.
- **Wall kick:** press jump in the air next to a wall to bounce off it. You get 2 per jump.
- **Slingshot:** slide into the ramp with the orange stripe to launch up.
- **Flow:** the bar at the bottom of the screen. Perfect hops, slide-jumps and wall kicks fill it, and each tier
  raises your top speed (30 → 36 → 42). Filling it completely starts **Overflow**: top speed 48 for 4 seconds.
  Standing still on the ground drains it.

## Phase 1 test checklist

Go through these in Studio and note anything that feels off:

- [ ] Walking feels snappy: you get to full speed quickly and stop quickly.
- [ ] Jumping feels snappy, not floaty.
- [ ] Holding Space does NOT auto-hop. Every hop needs a fresh press.
- [ ] Hopping right as you land keeps speed. The SPEED number on the HUD should climb.
- [ ] Air strafing (A/D + turning the mouse) gains speed.
- [ ] Sliding gives a boost, and the camera dips and tilts.
- [ ] Sliding down the 10°/20°/30° slopes gains speed, and steeper ones gain more.
- [ ] Slide-jump keeps your speed.
- [ ] Wall kicks work in the alley, and a third kick before landing doesn't work.
- [ ] The Slingshot launches you onto the landing platform.
- [ ] The Flow bar fills, changes color, and Overflow happens at 100.
- [ ] Speed caps hold: the HUD never goes above the current tier's cap.
- [ ] You never get stuck on ramp edges or walls.
- [ ] No red errors in the Output window (View → Output).
- [ ] Anti-cheat: normal play never prints "[AntiCheat] ... pulled back" in Output.
- [ ] It feels the same with the frame rate cap at 60 and at 240. To change the cap while playing, press Esc →
      Settings → Maximum Frame Rate.

All the numbers are in `src/shared/Config/MovementConfig.luau`. Change one, save, and Play again.

---

## Project layout

```
default.project.json          Rojo project: maps these folders into Studio
src/shared/                   → ReplicatedStorage.Shared (used by client and server)
  Config/MovementConfig.luau  every movement number
  Util/Spring.luau            smooth spring math for the camera
src/server/                   → ServerScriptService.Server
  Main.server.luau            sets gravity, builds the test map, starts anti-cheat
  Services/AntiCheatService   server speed check
  Services/TestMapBuilder     builds the gray test map
src/client/                   → StarterPlayerScripts.Client
  Main.client.luau            starts the controllers
  Controllers/MovementController   bhop, slide, wall kick, Slingshot, Flow
  Controllers/CameraController     first person, camera dip/tilt, FOV
  Controllers/DebugHud              temporary speed/Flow readout
```

## Next up: Phase 2

The VANTA sniper: scoping, quickscopes, hit registration with lag compensation, damage, death and respawn.
