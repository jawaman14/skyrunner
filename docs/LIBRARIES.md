# Open-source Godot libraries: what fits Skyrunner

A survey of free and libre Godot 4 add-ons and projects on GitHub (September 2026), judged against
this game's constraints:

- The simulation is plain GDScript that must stay bit-identical to the archived Python replays
  (the parity tests). Anything that replaces sim code has to earn that risk.
- Screenshots, videos and CI run on the compatibility renderer (llvmpipe, no GPU), so compute
  shaders and Forward+-only effects can only be an optional extra.
- Everything must be MIT, CC0 or similar, vendored with its licence.

## Adopted

| Library | Licence | What it does here |
|---|---|---|
| [Debug Menu](https://github.com/godot-extended-libraries/godot-debug-menu) (Calinou) | MIT | F6 in the 3D view: FPS, frame-time graphs, CPU/GPU times, hardware. Vendored in `addons/debug_menu/` without its editor plugin; loaded on demand (its own F3 binding would clash with the AI pilot) and skipped headless (its hardware-query thread never returns without a GPU). Useful for checking the cost of the animated characters and the island. |
| [Dialogue Manager](https://github.com/nathanhoad/godot_dialogue_manager) (Nathan Hoad), v3.10.5 | MIT | The conversations with the Family (Sal Moretti) and the General's aide (Captain Ibarra), written as scripts in `dialogue/*.dialogue`. Only the runtime is vendored (`addons/dialogue_manager/`, pinned in `UPSTREAM.txt`); v3.x is the line for Godot 4.4 (v4 needs 4.6). No plugin, autoload or import step: `scripts/game/talk.gd` instances the manager and compiles the scripts from text. The scripts act through the seat's permission-checked commands, so they work from a remote seat too. Our own balloon (`scripts/ui/talk_balloon.gd`) draws them in the game's style. |
| [Input Helper](https://github.com/nathanhoad/godot_input_helper) (Nathan Hoad), v4.7.0 | MIT | Rebinding the flight keys and gamepad buttons (F8), and naming a button for the pad in use (Xbox, PlayStation, Switch, Steam Deck). The runtime only, instanced on demand (`scripts/game/controls_config.gd`). We save the events ourselves: its text format turns physical keys into layout keycodes and pins joypad buttons to pad 0. |
| [SimpleGodotCRTShader](https://github.com/henriquelalves/SimpleGodotCRTShader) (Henrique Lacreta Alves) | MIT | The F9 VHS filter, with gentler uniforms than the demo's (`scripts/render/screen_filter.gd`). |
| [GATO screen filters](https://github.com/Nokorpo/gato-godot-accessibility-toolkit) (Iseltec) | MPL-2.0 | Its colour-blindness matrices: the F9 simulations and `test_accessibility`, which found the neon palette failing and checks the colour-safe one. The shader is vendored unmodified, with its licence (MPL is per file). |
| [Kenney Particle Pack](https://github.com/shorepine/kenney) | CC0 | Fire, flame, smoke, spark, splash-ring and dirt sprites (`assets/fx/kenney_particles/`, 128 px) for `scripts/render/fx.gd`: burning wrecks, smoking stash houses, RPG blasts, splashes when bales hit the sea. |
| [KayKit City Builder Bits](https://github.com/KayKit-Game-Assets/KayKit-City-Builder-Bits-1.0) (Kay Lousberg) | CC0 | The street furniture in town: lamp posts with their arms over the road (the glowing heads light up at night), traffic lights at the junction, hydrants, benches, dumpsters and bins (`assets/models/kaykit/city/`). |
| [Jolt Physics](https://github.com/godotengine/godot) (built into Godot since 4.4) | MIT | The 3D physics engine (`physics/3d/physics_engine`). All 386 tests pass on it; only the on-foot colliders and the blast debris use physics. The simulation never does. |
| [Kenney UI Audio](https://github.com/Calinou/kenney-ui-audio) (via Calinou) | CC0 | The UI's clicks (a conversation's answer, toggles) in `assets/audio/kenney_ui/`. |
| [Kenney's 3D kits](https://github.com/shorepine/kenney) | CC0 | The people, cars, guns, boats and palms (`assets/models/kenney/`, see the README). |
| [JSBSim](https://github.com/JSBSim-Team/jsbsim) | LGPL-2.1 | Was the flight model, through our own GDExtension. Replaced by the game's own GDScript model (`FlightDynamics`), which reads JSBSim's aircraft data files; see [PORTING.md](PORTING.md). |

## Worth adopting next

| Library | Licence | Where it would go | Cost / risk |
|---|---|---|---|
| Dialogue Manager, further | MIT | Adopted (above) for the Family and the General; the Company's contact and a defector's plea are the next scripts to write. | Low: a new `.dialogue` file and a key. |
| [Phantom Camera](https://github.com/ramokz/phantom-camera) | MIT | The demo tours and cinematic shots (follow, framing, tweened cuts) instead of hand-lerped cameras in `tools/*_tour.gd`. | Low: tools only. |
| [netfox](https://github.com/foxssake/netfox) | MIT | Lag compensation and client prediction for the remote pilot seat, or for on-foot combat between human players. | High: our protocol v3 is authoritative and snapshot-based, so this would be a partial adoption at most. |
| [LimboAI](https://github.com/limbonaut/limboai) or [Beehave](https://github.com/bitbrain/beehave) | MIT | Behaviour trees for new AI that isn't in the parity replays (the Family's and the island's actors, squad tactics). | Medium: the current utility and state code is tested and deterministic; a behaviour tree must keep its own RNG streams. |

## The free lists, second pass (September 2026)

Went through [awesome-godot](https://github.com/godotengine/awesome-godot) section by section and
[awesome-cc0](https://github.com/madjin/awesome-cc0) for free assets. The gap they exposed was
**sound**: the game had none but a synthesized heartbeat.
- The lists' CC0 audio is almost all on websites (Freesound, OpenGameArt, Free Music Archive), not
  on GitHub, and this build's network can't reach those sites.
- The one GitHub-hosted CC0 pack, Kenney's UI audio, is now in.
- Everything else is synthesized in `scripts/game/sound.gd`, which needs no licence:
  - the engine and propeller, pitched by the engine RPM;
  - the wind, the stall horn and the tyres;
  - the radio's squelch;
  - gunfire at the ground war's fights and from your own gun;
  - police helicopters' rotors, cruisers' sirens and the go-fasts' outboards;
  - surf, rain and thunder;
  - an 80s synth station (F7).

  Listen to samples in `docs/audio/`.

| From the lists | Licence | Verdict |
|---|---|---|
| [Event Audio](https://github.com/bbbscarter/event-audio-godot) | MIT | Fire-and-forget audio events. Our soundscape is small enough to own; worth it if the sound grows to hundreds of cues. |
| [Wwise](https://github.com/alessandrofama/wwise-godot-integration), [FMOD GD4](https://github.com/summertimejordi/fmod_gd4) | proprietary middleware | Not a fit: licensing and a sound-design toolchain for a synthesized soundscape. |
| [Input Helper](https://github.com/nathanhoad/godot_input_helper) | MIT | Adopted in the third pass (above). |
| [Virtual Joystick](https://github.com/MarcoFazioRandom/Virtual-Joystick-Godot) | MIT | Only if a touch build happens. |
| [NobodyWho](https://github.com/nobodywho-ooo/nobodywho) | EUPL | Local LLMs for NPC dialogue: tempting for Sal, Ibarra and the lawyers, but it needs model files of gigabytes and a GPU. An opt-in experiment at most, next to the written dialogue. |
| [Dialogic](https://github.com/dialogic-godot/dialogic) | MIT | Covered: Dialogue Manager does the conversations. |
| [Juicee](https://github.com/Kelpekk/Juicee) | MIT | Game-feel effects (shake, hit-stop): small wins for gunplay; the graph editor is more than we need. |
| [Godot Doctor](https://github.com/codevogel/godot_doctor), [Signal Lens](https://github.com/yannlemos/signal-lens) | MIT | Editor-side debugging; the headless test suite covers what they'd catch for us. |
| [TerraBrush](https://github.com/spimort/TerraBrush), [ProtonGraph](https://github.com/protongraph/protongraph) | MIT | Editor terrain and procedural graphs: the terrain is generated by the sim's own code and read by it (as with Terrain3D). |
| [VitaVehicle](https://jreo.itch.io/rcp4) | - | Raycast cars: our cars are sim-driven squads on a road graph, not player-driven. |

## The lists, third pass (September 2026)

I went back over [awesome-godot](https://github.com/godotengine/awesome-godot) and, beyond it, the official
[demo projects](https://github.com/godotengine/godot-demo-projects), the
[GATO accessibility toolkit](https://github.com/Nokorpo/gato-godot-accessibility-toolkit) and the KayKit CC0 kits.
Only GitHub is reachable from the build box, so the Asset Library, Godot Shaders, Poly Haven, OpenGameArt and
Freesound were out of reach. This pass exposed two gaps:

- **Controls.** The joystick code assumed one gamepad: left stick for the yoke, right stick X for the rudder, triggers for the throttle.
  - Real sim hardware is a yoke with its own throttle axis, rudder pedals on a second USB device, and toe brakes.
  - Input Helper is built for gamepads and has no axis binding per device, so `scripts/game/flight_axes.gd` does that part:
    - you bind a control by moving it;
    - devices are matched by name;
    - invert, deadzone and expo per control.

  Input Helper does the keys and buttons.
- **Colour.** GATO's colour-blindness matrices, applied to the game's colours and measured as CIE76 ΔE:

| Colours | Worst pair | ΔE | Verdict |
|---|---|---|---|
| Factions on the map (org / rival / police) | org vs rival, tritanopia | 39 | fine |
| Faction suits | org vs police, tritanopia | 61 | fine |
| Neon status colours | GREEN vs PINK, protanopia | **4** | fails. So do RED vs AMBER under deuteranopia (15) and AMBER vs PINK under tritanopia (11). |
| Colour-safe status colours | GREEN vs CYAN, tritanopia | 22 | passes (≥ 20) |

The simulation shader only shows the problem; the colour-safe palette is the fix for players.

| Also looked at | Licence | Verdict |
|---|---|---|
| [GATO text-to-speech](https://github.com/Nokorpo/gato-godot-accessibility-toolkit) | MPL-2.0 | Done in the fourth pass. Its plugin wraps Godot's own `DisplayServer.tts_*`, so `scripts/game/speech.gd` calls that directly: conversations and radio calls, read aloud (F8). |
| [GodotShaderWarmup](https://github.com/Koisuji02/GodotShaderWarmup) | MIT | Still not adopted. It's a native binary per platform, and first-sight stutter can't be measured on this GPU-less build box. Godot has had a built-in shader baker that does the same job since 4.5; the project is on 4.7 with it on in the export presets, so measure with F6 before adding anything. |
| [Phantom Camera](https://github.com/ramokz/phantom-camera), [Shaker](https://github.com/Eneskp3441/Shaker) | MIT | Tour cameras; screen shake for gunfire and turbulence. Small, later. |
| [Maaack's Game/Menus Template](https://github.com/Maaack/Godot-Game-Template) | MIT | We have our own lobby and menus. |
| [GdUnit4](https://github.com/MikeSchulze/gdUnit4), [Vest](https://github.com/foxssake/vest) | MIT | We have our own runner. |
| [gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit) | MIT | gdlint/gdformat in CI: worth a try, but noisy on a codebase this size until it's configured. |
| [Godot SQLite](https://github.com/2shady4u/godot-sqlite), [Talo](https://github.com/TaloDev/godot) | MIT | Saves are JSON and the game is self-hosted; nothing to gain. |
| [License Manager](https://kenyoni-software.github.io/godot-addons/addons/licenses) | MIT | Could generate an in-game credits screen from the licences we already vendor. |
| [KayKit City Builder Bits](https://github.com/KayKit-Game-Assets) | CC0 | Adopted in the fourth pass (above). |
| [Simplified Flight Simulation](https://github.com/fbcosentino/godot-simplified-flightsim) | MIT | Too simplified: our own model reads full aircraft data (aero tables, engines, propellers, gear). |

## The fourth pass: physics, textures, weather, fire, water, inventory (September 2026)

The gaps asked about, checked one by one on GitHub (the only reachable source):

| Want | Looked at | Verdict |
|---|---|---|
| Fire, smoke, explosions | [GDQuest godot-visual-effects](https://github.com/GDQuest/godot-visual-effects), [Kenney Particle Pack](https://github.com/shorepine/kenney) | GDQuest's shaders are MIT, but its art is **CC-BY-NC-SA** (non-commercial), so none of it was copied. The effects are ours: Kenney's CC0 sprites on `CPUParticles3D`, which draws the same on every renderer, the compatibility one included. |
| Water | [godot4-oceanfft](https://github.com/tessarakkt/godot4-oceanfft), [GodotOceanWaves](https://github.com/2Retr0/GodotOceanWaves), [Waterways](https://github.com/Arnklit/WaterGenGodot) | FFT oceans need compute shaders (Forward+ only), and Waterways is for Godot 3 rivers. Our ocean shader gained rain rings instead (below), plus splashes. |
| Rain and weather | [Sky3D](https://github.com/TokisanGames/Sky3D) (MIT, all renderers) | It would replace a sky we already have (sun, moon phases, clouds, a storm deck, lightning). What was missing was the world *getting wet*: a `rain_wet` shader global now darkens the ground and facades, puts a sheen on the roads, and rings the sea. It soaks through in about 2.5 minutes of storm and dries over about 15. |
| Fog | Godot's `FogVolume` (Forward+ only), Sky3D's fog | Storm fog already closes in. Sea fog is now weather in its own right (DESIGN §20). It's opt-in and has its own random stream, so the parity replays are untouched, and it's drawn as the environment's exponential fog, which works on every renderer. |
| Physics | Jolt (built into Godot since 4.4), [godot-jolt](https://github.com/godot-jolt/godot-jolt) (now archived upstream) | Switched to the built-in Jolt. Blasts now throw debris that tumbles and settles on the ground (capped, and it clears itself). Bales stay simulation-driven, because the airdrop's outcome is the simulation's. |
| Textures | [Kenney Prototype Textures](https://github.com/shorepine/kenney); Poly Haven and ambientCG are unreachable (not on GitHub) | The terrain, city and water are procedural (`texgen.gd`, splat shaders) at any resolution. Photo textures would clash with the low-poly look, so nothing was taken. |
| Inventory | [GLoot](https://github.com/peter-kish/gloot) (MIT, 4.4+), [Expresso Inventory System](https://github.com/expressobits/inventory-system) (MIT, C++), [Inventory Manager](https://github.com/Rubonnek/inventory-manager) | GLoot is the best of them, but its `Inventory` is a scene-tree Node, and ours has to live in the host-authoritative simulation and replicate. An on-foot pack of six kinds of thing is about 100 lines of `FootCombat`: it has a weight limit, slows you when heavy, keeps the other gun when you switch, takes and returns to the armoury, and holds medkits. Arrested, it becomes the task force's evidence. GLoot is the pick if inventory grows into containers, trading or grids. |
| Street props | [KayKit City Builder Bits](https://github.com/KayKit-Game-Assets/KayKit-City-Builder-Bits-1.0) | Adopted (above). |
| Read aloud | GATO TTS | Adopted as Godot's own TTS (above). |

## Looked at, not a fit

| Library | Why not |
|---|---|
| [godot4-oceanfft](https://github.com/tessarakkt/godot4-oceanfft) (FFT ocean, buoyancy) | Compute shaders: Forward+ only. It could be an optional "ultra" water later; boats in the sim are kinematic anyway. |
| [Gerstner waves and buoyancy](https://github.com/stvgale/Gerstner-Waves-Buoyancy-Effects-Godot-4), [Godot-Ocean-Shader](https://github.com/immaculate-lift-studio/Godot-Ocean-Shader) | Our ocean shader already does Gerstner-style waves; nothing to gain. |
| [Terrain3D](https://github.com/TokisanGames/Terrain3D) | The terrain is generated by the sim's own code and read by it (radar line-of-sight, landings), so it can't be swapped for an editor terrain. |
| [GodotJSBSim](https://github.com/lewhfree/GodotJSBSim), [jsbgodot](https://github.com/chunky/jsbgodot) | GDExtensions: a compiler per platform, which is what the game left behind. |
| [GUT](https://github.com/bitwes/Gut) | We have our own headless test runner (`tools/test.sh`, 320+ tests); moving buys nothing. |

Sources: [awesome-godot](https://github.com/godotengine/awesome-godot) (the curated list), and each project's repository above.

## Godot 4.7

The project moved from 4.4.1 to **4.7.2** (the latest stable). The worries that had held it back didn't come true:
- **JSBSim.** The GDExtension (built against the 4.4.1 `godot-cpp`) loaded in 4.7 unchanged. It has since been removed altogether: the game is GDScript only, with its own flight model ([PORTING.md](PORTING.md), "Leaving JSBSim"), so nothing needs rebuilding for a new Godot or a new platform.
- **Vendored addons.** Dialogue Manager v3.10.5, Input Helper, the CRT and colour-blindness shaders and the Kenney and KayKit kits all work: all 459 tests pass on 4.7.2, the same as on 4.4.1.
- **One break.** 4.7 enforces an overridden virtual's return type: the screenshot tools' `_process` (a `MainLoop` override, which returns a bool that quits when true) now declares `-> bool` and returns false.
- **Rendering.** The same frames render identically under the compatibility renderer (llvmpipe).
- **The shader baker** (since 4.5) is switched on in the export presets, so a release build compiles its shaders ahead of time instead of stuttering on first sight. First-sight frame times still want measuring on real hardware (F6).

## The fifth pass: filling the world in (October 2026)

The game's art was thin: 8 cars, 2 boats, 10 characters, 6 palms and 6 street props from three CC0 kits. A pass over the
free CC0 libraries for what fills a 1980s tropical coast, all vendored with their licences (assets/models/*/LICENSE.txt,
README.txt or UPSTREAM.txt) and covered by tests/test_assets.gd. This is the stock the render modules draw from (`ModelLib` loads by path); what is wired in so far is listed below.

| Pack | Licence | Models | Where it goes |
|---|---|---|---|
| Kenney [Car Kit](https://kenney.nl/assets/car-kit), [Blocky Characters](https://kenney.nl/assets/blocky-characters), [Watercraft](https://kenney.nl/assets/watercraft-kit), [Weapon Pack](https://kenney.nl/assets/weapon-pack): the rest of each | CC0 | 50 / 18 / 46 / 37 | Traffic and squads' vehicles (ambulance, vans, kart racers), the other 8 faces for crews and the Family, more boats, more guns. |
| Kenney [Nature Kit](https://kenney.nl/assets/nature-kit) | CC0 | 329 | Rocks, bushes, logs, cliffs, grass and trees for jungle, mangrove and the quarry (only the palms were in). |
| Kenney City Kits: [Commercial](https://kenney.nl/assets/city-kit-commercial), [Suburban](https://kenney.nl/assets/city-kit-suburban), Industrial, Roads; [Modular Buildings](https://kenney.nl/assets/modular-buildings); [Retro Urban](https://kenney.nl/assets/retro-urban-kit) | CC0 | 41 / 40 / 25 / 72 / 108 / 124 | Building variety for downtown, the barrio and the port; Retro Urban is the closest to the 80s street. |
| Kenney [Furniture Kit](https://kenney.nl/assets/furniture-kit) | CC0 | 140 | The villa, the hangars and offices, the lawyer's and the General's rooms. |
| Kenney [Pirate Kit](https://kenney.nl/assets/pirate-kit), [Survival Kit](https://kenney.nl/assets/survival-kit), [Factory Kit](https://kenney.nl/assets/factory-kit) | CC0 | 72 / 80 / 143 | Docks, barrels and crates for the port and the cay; tents, crates and fires for the jungle camp; warehouses. |
| [KayKit City Builder Bits](https://github.com/KayKit-Game-Assets/KayKit-City-Builder-Bits-1.0): all of the free pack | CC0 | 41 (6 were in) | Buildings, roads, park tiles, vehicles, trees. |
| Quaternius [Downtown City MegaKit](https://quaternius.itch.io/downtown-city-megakit) (free Standard) | CC0 | 153 | Modular downtown facades, shopfronts and street pieces. |
| Quaternius [Stylized Nature MegaKit](https://quaternius.itch.io/stylized-nature-megakit) (free Standard), [Ultimate Nature Pack](https://quaternius.itch.io/150-lowpoly-nature-models) | CC0 | 68 / 150 | A second, painterly look for the jungle and the island's flora. |
| Quaternius [Realistic Car Pack](https://quaternius.itch.io/lowpoly-cars), [Modular Street Pack](https://quaternius.itch.io/lowpoly-modular-street) | CC0 | 7 / 25 | A different set of cars; street furniture and signs. |
| Kenney 2D: Input Prompts, Game Icons, UI Pack, Cursor Pack (crosshairs), Minimap, Flags, Map Pack, Explosions, Emotes, Road Textures | CC0 | ~3,200 sprites | Button glyphs for the controls screens; HUD icons; the on-foot gun sight; the 2D desks' map symbols; the flags of the island's neighbours. See assets/ui/README.txt. |

How they were fetched: Kenney's from the CC0 mirror [shorepine/kenney](https://github.com/shorepine/kenney) (glTF, 110 MB sparse-cloned,
only the kits above), KayKit's from its repository, Quaternius's from the packs' own itch.io pages (their free "Standard" downloads;
his GitHub mirrors hold USD, which Godot cannot import). The two MegaKits' textures were shrunk from 123 MB to 20 MB (1024 px
base colour, 512 px normal and ORM maps). Godot 4.7 imports the three FBX-only Quaternius packs natively; `--import` ran clean.

| Looked at and left | Why |
|---|---|
| Quaternius Ships and Public Transport packs | On quaternius.com only; no itch.io page found under any name tried. |
| [game-icons.net](https://game-icons.net/about.html) (about 4,000 icons) | CC BY 3.0: needs a credits screen first (License Manager, above). |
| Kenney UI Pack's flat look | Vendored, but the game's neon HUD palette is its own; use for shapes, not colours. |
| Poly Pizza's aircraft | The licences are per model, and Google-Poly-era ones are usually CC BY; each would need checking. The game's aircraft are built from the flight model's data anyway. |
| Aircraft and airfield props | No good CC0 pack found (a [low-poly helicopter on itch](https://kumasousa.itch.io/low-poly-helicopter-with-animations) and a [toy airplane on OpenGameArt](https://opengameart.org/content/toy-airplane-lowpoly) are the only CC0 leads). |

### What is in the world now

| Pack | Where | What it does |
|---|---|---|
| Kenney City Kits (Commercial, Suburban, Industrial) | `scripts/render/city_dress.gd`, `shaders/city_lot.gdshader` | Each of the city's 6,600 boxes is cut into 1-9 lots and every lot gets a real building (skyscrapers for towers, commercial blocks, houses where it is low, sheds for warehouses), scaled to the lot and the box's height, turned to face the nearest street, tinted the box's pastel, with lit windows, a roofline trim band and the neon strip at night. Drawn in 300 m chunks within 700 m (high) or 450 m (medium); the shader boxes take over beyond with a fade. Off on low quality. |
| (road data, no pack) | `CityRender._road_details` | Lane markings (dashed yellow centre, white edge lines) and raised concrete pavements with a kerb face along the town's roads. |
| Kenney Nature Kit | `scripts/render/scenery.gd`, `ModelLib.merged_mesh` | Boulders and crags on steep and rocky ground, small rocks, bushes in the scrub and jungle, detailed palms along the beaches: a hash-seeded 120 m grid, in 1 km chunks with a range, off on low quality. The rocks get a grey-brown stone material (the kit paints them in its palms' palette). |

The export presets (`export_presets.cfg`) leave out every pack nothing uses yet - the other Kenney kits, all of Quaternius and the 2D
sprites - and `tests/test_export_filter.gd` fails if a used pack is excluded or an unused one ships. When a pack is wired in, take its
line out of `exclude_filter` in all three presets.

Not done: collision on the city's buildings (the on-foot walker passes through them, as before), roof details and ground-floor awnings
from the Commercial kit's `detail-*` pieces, crosswalks, furniture in the hangars (the villa's desk, map table, sofas and bookcase and the club's bar stools, sofas, speakers and office are furnished, in a PR: `Buildings.Kit.prop`, at 2.4x because the kit is dolls'-house sized), docks and cargo from the Pirate kit
at the port, Quaternius's downtown pieces, and the 2D packs (glyphs for the controls screens, the crosshair, map symbols).
