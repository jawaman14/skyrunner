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

  To hear samples, render them: `godot --headless --script res://tools/sound_demo.gd -- <out dir>`.

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
| [GATO text-to-speech](https://github.com/Nokorpo/gato-godot-accessibility-toolkit) | MPL-2.0 | Previously implemented through Godot's own TTS API; read-aloud was removed in #385. The GATO TTS plugin is not a runtime dependency. |
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
| Read aloud | GATO TTS | Retired in #385 (above). |

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

The city's buildings are now solid (`CityDress.colliders`, one box per building: the walker and the car stop against them). Not done: roof details and ground-floor awnings
from the Commercial kit's `detail-*` pieces, crosswalks, furniture in the hangars (the villa's desk, map table, sofas and bookcase and the club's bar stools, sofas, speakers and office are furnished,: `Buildings.Kit.prop`, at 2.4x because the kit is dolls'-house sized), docks and cargo from the Pirate kit
at the port, Quaternius's downtown pieces, and the 2D packs (glyphs for the controls screens, the crosshair, map symbols).

**Removed in October 2026 (unused; CC0; fetch again if needed):** Kenney survival, factory, retro-urban, modular-buildings and city-roads kits; Quaternius Stylized Nature, Ultimate Nature, Realistic Car and Modular Street packs; all of Kenney's 2D packs (Input Prompts, Game Icons, UI Pack, Cursors, Minimap, Flags, Map Pack, Explosions, Emotes, Road Textures). The flags are real countries' flags and the game's world is fictional; the cursors are thin outlines or plain white and read worse than the system pointer on the game's dark and bright scenes; the rest had no place in the layout.

## Candidates from the GitHub `godot` topic (18 October 2026)

The owner asked for the top 500 repositories tagged [godot](https://github.com/topics/godot) (by stars) to be read for names and descriptions that could help. About 50 stood out; the rest are engines, tutorials, templates, 2D genres or tools for other languages. **This is a list to assess, not a decision to adopt anything.** Only names, descriptions, languages and licences were read, nothing was run. The project's limits decide: pure GDScript with no native add-on, a deterministic simulation, fictional content, and licences compatible with MIT (GPL and unclear licences are marked). A row moves to the main table above only after a prototype or a read of its source.

### Map, roads and world

| Repository | Stars | Language | Licence | Could help with | First look |
|---|---|---|---|---|---|
| [TheDuckCow/godot-road-generator](https://github.com/TheDuckCow/godot-road-generator) | 1235 | GDScript | MIT | Map redesign L5: road meshes, junctions, lane-following traffic for the city's ambient life | Best fit on the list. Our roads are a baked graph; look at its lane and junction geometry, and at traffic that follows lanes |
| [AlexeyBond/godot-constraint-solving](https://github.com/AlexeyBond/godot-constraint-solving) | 465 | GDScript | MIT | Valle Verde (D-46): wave-function-collapse for blocks, lots and streets | A generator idea for L6; the output must stay deterministic and baked |
| [Arnklit/Waterways](https://github.com/Arnklit/Waterways) | 1337 | GDScript | MIT | Rio Negro river and estuary meshes with flow and foam from curves | Assessed: Godot 3 only (project config_version 4, last change 2022, `.shader` files). Skip; the flow-map idea stays |
| [Yogoda/ZoneLoadingSystem](https://github.com/Yogoda/ZoneLoadingSystem) | 238 | GDScript | CC0-1.0 | Streaming a 32 km map by zone | CC0. Check against our chunked rendering before adding anything |
| [levinzonr/godot-asset-placer](https://github.com/levinzonr/godot-asset-placer) | 253 | GDScript | MIT | Placing and managing 3D assets in the editor (L7 sites, L9 props) | An editor tool for the asset catalogue workflow; our placement is baked data |
| [iiMidknightii/PathMesh3D](https://github.com/iiMidknightii/PathMesh3D) | 147 | C++ | MIT | Extruding fences, kerbs and rails along a path | C++ GDExtension: ideas only, since the project is pure GDScript |
| [2Retr0/GodotGrass](https://github.com/2Retr0/GodotGrass) | 695 | C# | MIT | Per-blade grass for the plain and verges | Cost on the target machines is the question; prototype only |
| [JekSun97/gdTree3D](https://github.com/JekSun97/gdTree3D) | 382 | C++ | NOASSERTION | Procedural trees | Licence is unclear; do not use until clarified |
| [openfw-game/OpenLiberty](https://github.com/openfw-game/OpenLiberty) | 468 | GDScript | MIT | Streaming a GTA-era open world with period models | A reference for how a city of this style is streamed |
| [godot-extended-libraries/godot-lod](https://github.com/godot-extended-libraries/godot-lod) | 247 | GDScript | MIT | LOD for the city's models | Godot 3.x; read for the approach only |
| [DmitriySalnikov/godot_debug_draw_3d](https://github.com/DmitriySalnikov/godot_debug_draw_3d) | 1073 | C++ | NOASSERTION | Drawing the map audit's overlay in the 3D view | Native add-on and a custom licence: probably draw our own lines |

### Flight and vehicles

| Repository | Stars | Language | Licence | Could help with | First look |
|---|---|---|---|---|---|
| [addmix/godot_aerodynamic_physics](https://github.com/addmix/godot_aerodynamic_physics) | 204 | GDScript | MIT | Cross-checking our flight model against another aerodynamic model | Reference only; our model reads JSBSim data and must stay deterministic |
| [GDQuest/godot-steering-ai-framework](https://github.com/GDQuest/godot-steering-ai-framework) | 1582 | GDScript | MIT | Steering for ambient traffic, squads and boats | MIT and pure GDScript. Check it against our own route following |
| [HungryProton/proton_trail](https://github.com/HungryProton/proton_trail) | 150 | GDScript | MIT | 3D trails: contrails, wingtip vapour, tyre smoke | Small add-on for the effects layer |
| [appsinacup/godot-rapier-physics](https://github.com/appsinacup/godot-rapier-physics) | 1027 | Rust | MIT | Deterministic physics with state serialization | Native. Interesting for replays, but our sim does not use engine physics |

### Interface and polish (the epic order, D-48)

| Repository | Stars | Language | Licence | Could help with | First look |
|---|---|---|---|---|---|
| [rsubtil/controller_icons](https://github.com/rsubtil/controller_icons) | 445 | GDScript | MIT | #134/#148 first-use hints and #138 readability: key and controller prompts that follow the device | Strong fit for Tier 1 items 3 and 5. Pure GDScript |
| [zijcht/godot-game-settings](https://github.com/zijcht/godot-game-settings) | 524 | GDScript | MIT | #137 settings and pause menu | Compare with our settings code before adopting |
| [Inspiaaa/ThemeGen](https://github.com/Inspiaaa/ThemeGen) | 267 | GDScript | MIT | One programmatic theme for UIStyle and GameMenu (#138) | Could replace hand-built themes; check how it works with our shared shell |
| [tavurth/godot-radial-menu](https://github.com/tavurth/godot-radial-menu) | 350 | GDScript | MIT | A radial menu for squad orders or quick phone actions | Idea for the phone hub's quick keys |
| [murikistudio/simple-gui-transitions](https://github.com/murikistudio/simple-gui-transitions) | 205 | GDScript | MIT | Menu transitions | Polish only |
| [MrEliptik/godot_ui_components](https://github.com/MrEliptik/godot_ui_components) | 775 | GDScript | MIT | UI component designs | Reference for layouts |
| [Kubulambula/Godot-GDShell](https://github.com/Kubulambula/Godot-GDShell) | 230 | GDScript | MIT | A developer console for QA commands | Our session commands already exist; a console could call them |
| [Ark2000/PankuConsole](https://github.com/Ark2000/PankuConsole) | 1437 | GDScript | MIT | Real-time debugging toolkit | Dev builds only |
| [russmatney/log.gd](https://github.com/russmatney/log.gd) | 140 | GDScript | MIT | A readable logger for the sim and tests | Tiny; would not touch determinism |

### Look and sound (presentation layers, D-23)

| Repository | Stars | Language | Licence | Could help with | First look |
|---|---|---|---|---|---|
| [AnalogFeelings/godot-psx](https://github.com/AnalogFeelings/godot-psx) | 152 | - | MIT | The PS2-era look (roadmap #380): PS1/PS2 shaders for models | Assessed: PS1 look (vertex snapping, affine warp), not PS2. Only the dither pass is useful; see below |
| [MenacingMecha/godot-psx-style-demo](https://github.com/MenacingMecha/godot-psx-style-demo) | 739 | GDScript | MIT | The same, with materials and a demo | MIT |
| [ahopness/GodotRetro](https://github.com/ahopness/GodotRetro) | 803 | GLSL | NOASSERTION | Retro compositor effects | Licence is unclear |
| [hugemenace/resonate](https://github.com/hugemenace/resonate) | 240 | GDScript | MIT | Music and sound management: pooling, crossfades | For the radio, stingers and per-district music (#167) |
| [nlaha/godot-midi](https://github.com/nlaha/godot-midi) | 147 | C++ | MIT | Playing MIDI for era music at small size | Assessed: native GDExtension for rhythm games. Skip |
| [kyzfrintin/Godot-Mixing-Desk](https://github.com/kyzfrintin/Godot-Mixing-Desk) | 673 | GDScript | MIT | Adaptive and procedural music (stingers) | Godot 3.3, so ideas only |
| [ikbencasdoei/godot-voip](https://github.com/ikbencasdoei/godot-voip) | 211 | Rust | MIT | Voice chat | We have our own voice layer; compare quality and latency |
| [cloudofoz/godot-smashthemesh](https://github.com/cloudofoz/godot-smashthemesh) | 497 | GDScript | MIT | Breaking meshes into fragments | Crash and explosion effects; check cost |
| [cloudofoz/godot-deformablemesh](https://github.com/cloudofoz/godot-deformablemesh) | 451 | GDScript | MIT | Run-time mesh deformation | Vehicle dents; check cost |

### Dialogue and story

| Repository | Stars | Language | Licence | Could help with | First look |
|---|---|---|---|---|---|
| [ephread/inkgd](https://github.com/ephread/inkgd) | 396 | GDScript | MIT | Branching story scripts in ink, in pure GDScript | An alternative to Dialogue Manager for Rafa's chapters; we already use Dialogue Manager, so only if it falls short |
| [viniciusgerevini/godot-clyde-dialogue](https://github.com/viniciusgerevini/godot-clyde-dialogue) | 149 | GDScript | MIT | A small dialogue language | Probably not needed |
| [TheWalruzz/godot-questify](https://github.com/TheWalruzz/godot-questify) | 255 | GDScript | MIT | Graph-based quest editor | Our story goals are code; read for the UI of goals |

### Networking and servers

| Repository | Stars | Language | Licence | Could help with | First look |
|---|---|---|---|---|---|
| [grazianobolla/godot-monke-net](https://github.com/grazianobolla/godot-monke-net) | 251 | C# | - | Client-server authoritative multiplayer | Reference for our host service |
| [heroiclabs/nakama + nakama-godot](https://github.com/heroiclabs/nakama) | 13520 | Go | Apache-2.0 | Matchmaking and accounts for dedicated servers | A server framework: a decision for the multiplayer step, not now |
| [0xFA11/MultiplayerNetworkingResources](https://github.com/0xFA11/MultiplayerNetworkingResources) | 8742 | C | - | A reading list on multiplayer networking | Reading |

### Testing, tools and agents

| Repository | Stars | Language | Licence | Could help with | First look |
|---|---|---|---|---|---|
| [GDQuest/GDScript-formatter](https://github.com/GDQuest/GDScript-formatter) | 478 | Rust | MIT | A faster formatter and linter pass for CI hygiene | Compare with gdscript-toolkit, which is already on the list |
| [abarichello/godot-ci](https://github.com/abarichello/godot-ci) | 1146 | Dockerfile | MIT | Export and deploy templates for CI | Compare with our workflow; ideas only |
| [satelliteoflove/godot-mcp](https://github.com/satelliteoflove/godot-mcp) | 178 | GDScript | MIT | Input injection, deterministic playtesting and live game state through MCP | Relevant to the #172 playtest protocol and the owner's screenshots; compare with our own MCP |
| [HaD0Yun/Doyunha-Gopeak](https://github.com/HaD0Yun/Doyunha-Gopeak) | 268 | TypeScript | MIT | MCP with screenshot capture, a GDScript language server and a debugger | Ideas for our MCP tools |
| [Coding-Solo/godot-mcp](https://github.com/Coding-Solo/godot-mcp) | 6135 | JavaScript | MIT | Launch, run and capture debug output through MCP | The best known Godot MCP; compare tools |
| [jame581/GodotPrompter](https://github.com/jame581/GodotPrompter) | 845 | JavaScript | MIT | Godot 4 skills for coding agents | Could improve how Claude and Codex write Godot; read the skills first |
| [gamedev-skills/awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) | 1582 | Python | Apache-2.0 | A directory of game-dev agent skills | A list to browse |
| [script-gd/gdcc](https://github.com/script-gd/gdcc) | 157 | Java | LGPL-3.0 | An ahead-of-time GDScript compiler | Would add native binaries and a build step; not for a pure-GDScript project today |
| [getsentry/sentry-godot](https://github.com/getsentry/sentry-godot) | 256 | C++ | MIT | Crash reporting | Sends data off the machine, which the owner's playtest-log decision rules out |

Not listed on purpose: engine forks and language bindings (Redot, godot-rust, the C#, Go, Kotlin, Lua and Nim bindings), ECS frameworks (the simulation has its own layers), 2D genre kits (platformer, roguelike, card, tower defence, tile and dual-grid tools), ad, store and platform SDKs, VR and Live2D tools, and editors and IDE plugins.

### Assessed after reading the source (18 October 2026)

I cloned the twelve most promising repositories into a scratch folder outside the project and read their README, layout,
licence and the code that matters. Nothing was run and nothing is added to the game. The verdicts, with what to do next:

| Repository | What it is | Verdict | Why, and the next step |
|---|---|---|---|
| [TheDuckCow/godot-road-generator](https://github.com/TheDuckCow/godot-road-generator) | 6,000 lines of editor-authored road nodes (RoadContainer, RoadPoint, segments, lanes), an n-gon intersection mesh (976 lines) and lane-following traffic agents; MIT; Godot 4.4+; "not feature complete" | **Borrow ideas, do not adopt** | Our roads are a planned and baked graph, not scene nodes, and the plugin is still changing. What we lack is junction geometry: read `procgen/intersection_ngon.gd` and `segment_geo.gd` before writing the map redesign's L5 junctions (`docs/MAP_REDESIGN.md`), and `road_lane_agent.gd` for how traffic follows a curve |
| [rsubtil/controller_icons](https://github.com/rsubtil/controller_icons) | 1,900 lines of GDScript; icons for keyboard, mouse and every common pad that follow the device and the remapped action; MIT; art is CC0 (Xelu), 4.3 MB | **Prototype** | Our game already registers every control as an `InputMap` action with key and joypad events (`scripts/game/controls_config.gd`), which is exactly what the add-on reads. One slice: show the real glyph in `KeyHints` and the first-use hints (Tier 1 items 3 and 5). Needs an autoload and an export-filter entry for the assets |
| [AnalogFeelings/godot-psx](https://github.com/AnalogFeelings/godot-psx) | Four shaders: lit and unlit PS1 surfaces, a full-screen dither with colour depth, a fade; MIT | **Write our own dither; skip the rest** | The PS1 vertex snapping and affine warping are the wrong era (the owner's direction is PS2). The dither is 30 lines using the standard 4x4 ordered pattern; its README says it derives from the DuckStation emulator, whose licence is not MIT. Write a clean banding-and-dither pass for the optional PS2 screen filter (`ScreenFilter.MODES`, `docs/ASSET_COVERAGE.md` item 8) |
| [AlexeyBond/godot-constraint-solving](https://github.com/AlexeyBond/godot-constraint-solving) | Wave-function collapse and a generic constraint solver for tile maps and grid maps; MIT | **Skip** | It cannot guarantee that all road tiles connect (its own README lists global constraints as not implemented), it draws on the global random generator (no per-item seeds), and it is tile-based. Valle Verde's streets should be a parametric grid bent to the terrain and clipped by the highway, built by our own tool |
| [Arnklit/Waterways](https://github.com/Arnklit/Waterways) | River meshes with flow and foam maps from bezier curves | **Skip** | Godot 3 (2022). Reading its flow-map filter passes is fine for the Rio Negro's water shader, but nothing can be used as it stands |
| [satelliteoflove/godot-mcp](https://github.com/satelliteoflove/godot-mcp) | A Node.js MCP server and an editor plugin: freeze the game clock, step time, step until a condition holds, inject real input, read live state as JSON, run GDScript in the running game; MIT; Godot 4.5+ | **Borrow ideas, do not adopt** | It adds Node and an editor plugin to a repository whose MCP is Python and whose runs are headless. The valuable idea for the playtest script (#172) is a deterministic stepping and state-digest tool: our simulation is already deterministic, so a "play N seconds with these inputs and give me a digest and a screenshot" tool in skyrunner-mcp would do the same job |
| [jame581/GodotPrompter](https://github.com/jame581/GodotPrompter) | 57 skills for coding agents (testing, save and load, shaders, optimisation, procedural generation, multiplayer, dedicated server); MIT; no telemetry | **Read selected skills, do not install** | The generic advice conflicts with our rules (GUT and gdUnit4 where we have our own test runner, autoload event buses, C# examples) and it installs a session-start hook that would add to the context every session. If a skill helps (`godot-optimization`, `shader-basics`, `procedural-generation`), copy the relevant lines into our docs |
| [addmix/godot_aerodynamic_physics](https://github.com/addmix/godot_aerodynamic_physics) | 4,000 lines: an aircraft as an engine `VehicleBody3D` with lift surfaces; MIT; a C++ port is in progress | **Skip** | It rides on the engine's vehicle-body physics, which is not deterministic; our flight model is our own, reads JSBSim data and is replayable. At most compare its lift-curve shape with ours |
| [GDQuest/godot-steering-ai-framework](https://github.com/GDQuest/godot-steering-ai-framework) | Steering behaviours (seek, arrive, pursue, avoid, follow a path) on plain vectors; MIT; last change September 2024 | **Skip for now** | The behaviours are not tied to engine physics, so it would be safe, but our traffic and squads already follow road-graph routes. Revisit only if crowd movement (the casino's patrons) needs it |
| [hugemenace/resonate](https://github.com/hugemenace/resonate) | A sound manager (pooled players, 2D and 3D, polyphony) and a music manager with stemmed tracks and crossfades; MIT; now maintained by Widgit Gaming | **Prototype when the presentation layers start** | Stems and crossfades are what per-district music and the stingers in D-34 need, and it is pure GDScript. The game's sounds are synthesised in `scripts/game/sound.gd` and the car radio plays recorded excerpts, so it would sit beside them, not replace them |
| [Yogoda/ZoneLoadingSystem](https://github.com/Yogoda/ZoneLoadingSystem) | Loading and unloading zones by trigger areas | **Skip** | Godot 3 and unmaintained. Our chunked MultiMeshes already handle the city |
| [grazianobolla/godot-monke-net](https://github.com/grazianobolla/godot-monke-net) | Client-authoritative multiplayer with prediction and interpolation | **Skip** | C#, and it needs the author's fork of Godot. Our host service and snapshots are our own |

Terrain3D (already on the main table as "cannot be swapped") was read again on 18 October at the owner's request:

| Repository | What it is | Verdict | Why |
|---|---|---|---|
| [TokisanGames/Terrain3D](https://github.com/TokisanGames/Terrain3D) | A C++ GDExtension: geometric clipmap terrain split into regions (256 m at 1 m spacing by default, up to 65 km), sculpting, holes, 32 textures, foliage instancing, collision; MIT; active (17 October) | **Do not adopt; borrow the data model** | It is native code that every platform and the headless server would need, and the simulation reads the terrain (radar line of sight, landings, roads, the pit exit) from its own baked height grid, so two terrains would be two sources of truth. What it shows is the answer to our real limit: our grid is 513 x 513 over 32 km, so one cell is 62.5 m. A fine regional height layer over the coarse grid, read in pure GDScript, is now written into the map plan (`docs/MAP_REDESIGN.md`, the height patches) |

Six more were read afterwards:

| Repository | What it is | Verdict | Why |
|---|---|---|---|
| [HungryProton/proton_trail](https://github.com/HungryProton/proton_trail) | One 256-line GDScript node that draws a 3D trail; MIT; last change 2023 | **Borrow** | Small enough to vendor with its licence, or to rewrite, for contrails, wingtip vapour and tyre smoke in the effects layer. Not needed until that work starts |
| [Inspiaaa/ThemeGen](https://github.com/Inspiaaa/ThemeGen) | One GDScript file that builds a `Theme` from code, with semantic colours and light and dark variations; MIT | **Skip, idea only** | `UIStyle` already builds our themes in code; the semantic-colour variations are the same idea as our accessibility palettes |
| [zijcht/godot-game-settings](https://github.com/zijcht/godot-game-settings) | A settings framework with ready-made components, its own save file and a glyph database; MIT; Godot 4.5 | **Skip** | It would replace our settings, controls and pause menus rather than add to them. Its glyph database overlaps `controller_icons` |
| [ikbencasdoei/godot-voip](https://github.com/ikbencasdoei/godot-voip) | Voice chat; MIT; last change August 2024 | **Skip** | It ships native code (an Opus extension); we have our own radio-style voice layer in pure GDScript |
| [nlaha/godot-midi](https://github.com/nlaha/godot-midi) | MIDI import and playback for rhythm games; MIT | **Skip** | A native GDExtension built for rhythm games; not pure GDScript |
| [GDQuest/GDScript-formatter](https://github.com/GDQuest/GDScript-formatter) | A Rust formatter and linter for GDScript | **Skip** | A native binary to download in CI, which is a supply-chain addition; `gdscript-toolkit` already covers the job |

**Next, in this order, if the owner agrees:** (1) read the road generator's intersection code while writing L5 (no project change);
(2) one `controller_icons` prototype slice behind `KeyHints`, with a screenshot; (3) write the dither banding pass for the screen filter;
(4) the stepping and digest tool for the playtest script. Resonate waits for the presentation layers.
