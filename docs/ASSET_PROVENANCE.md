# Asset provenance and runtime usage

Source inventory checked 7 October 2026. This register records checked-in licence
files and observed consumers; it does not imply every file in a kit is rendered.
Keep original licence notices. Code/add-on provenance is maintained separately in
[LIBRARIES.md](LIBRARIES.md).

| Asset group | Creator / source and licence record | Actual usage / adaptation |
|---|---|---|
| Kenney model kits | Kenney, https://kenney.nl; CC0 in `assets/models/kenney/LICENSE.txt` | `ModelLib` loads selected character, car, weapon and boat models. `CityDress` selects commercial/suburban/industrial buildings; `Scenery` selects nature props; `PortDress` selects Pirate Kit docks, boats and equipment. Selection is code-driven; importing a kit does not establish usage of every member. |
| Quaternius Downtown City MegaKit Standard | Quaternius; https://quaternius.itch.io/downtown-city-megakit; CC0 recorded in `assets/models/quaternius/README.txt`, downloaded 3 October 2026 | `DowntownDress.MODELS` selects `Building_Large_2`, `Building_Medium_2_001`, `Building_Small_1` for up to twelve San Telmo landmarks. Existing imported textures were resaved as PNG, base textures at most 1024 and normal/ORM at most 512, per the source README. Other kit parts are not established runtime consumers. |
| KayKit City Builder Bits 1.0 | Kay Lousberg, https://kaylousberg.com; CC0 in `assets/models/kaykit/city/LICENSE.txt` | `City` loads selected models from this folder. The licence's 25 August 2023 date is the asset creation date; acquisition date is not recorded. |
| UI Audio | Kenney; CC0 in `assets/audio/kenney_ui/LICENSE.txt` | `Sound` loads selected WAVs for interface feedback. |
| Particle sprites | Kenney; CC0 in `assets/fx/kenney_particles/LICENSE.txt` | `Fx` selects PNGs for CPU particles. |
| Kaushan Script | Pablo Impallari and Igino Marini; SIL OFL 1.1 in `assets/fonts/OFL-KaushanScript.txt` | `UIStyle.script()` loads the WOFF2 for script headings; fallback font if absent. Preserve Reserved Font Name and licence notice. |
| Monoton | Vernon Adams; SIL OFL 1.1 in `assets/fonts/OFL-Monoton.txt` | `UIStyle.neon()` loads the WOFF2 for neon display accents; fallback font if absent. Preserve Reserved Font Name and licence notice. |
| Period prop SVGs | Original Skyrunner project artwork; authorship and dimensions in `assets/props/README.md`; no separate asset licence declared there | `Buildings` uses `analogue_fuel_face.svg`, `pinned_notices.svg` and `fuel_drum_label.svg` on pump, workshop notices and fuel-cache drums. Original vector geometry/text, no external bitmap or font imports. These graphics do not create simulated fuel or inventory. |
| Stash storage interiors | Original Skyrunner modular geometry in `StashInterior`; project source licence, no external asset imports | Eight stash shells, thresholds, workbenches and steps reuse `Buildings` materials. Decorative papers and furniture do not represent stock. Site dimensions come from `SiteLayout`; logistics reads simulation state. Pitched roof collision uses the rendered slopes and end triangles. |
| HAR workshop equipment | Original Skyrunner modular geometry in `Buildings.workshop_tools`; project source licence, no external imports | HAR's board-equipped hangar uses a steel drawer chest, hand-screw vice and timber spanner rack. Existing batched materials, no additional collision/lights/random draws. Bench footprint and repair interaction remain unchanged. Preview tool is `tools/workshop_preview.gd`; this is one reference-area batch, not completion of the coastal art pass. |
| Archived radio excerpts | Original broadcasters/rightsholders; listener recordings sourced from Internet Archive | `CarRadio` reads `assets/radio/dial.json` and the station folders. **No reliable redistribution licence is recorded.** These are not covered by the CC0 kit licences. [The radio inventory](../assets/radio/README.md) records every clip, source item, adaptation and the owner's existing inclusion decision. User-added `user://radio` is not shipped. |

## Production rule for the remaining art pass

Use weathered period architecture/equipment, with neon concentrated in nightlife
and interface accents. Costa Brava is the reference area; ordinary houses remain
scenery. Preserve dimensions, performance and authoritative stock. Reuse materials
and distant LODs, and follow the independent Asset Bible's budgets in
[PR #119](https://github.com/jawaman14/skyrunner/pull/119); its historical additional
aircraft/chapter proposals are deferred by the current roadmap.

For each new batch record the exact source, author, licence notice, modifications,
runtime consumer and used subset before import. Import only assets actually used.
Record the fixed reference route and before/after frame time and memory separately;
this inventory is not performance or physical-access evidence. The complete coastal
airfield–road–stash–dock/service reference area remains unfinished.

## Exported notices

All three desktop export presets explicitly include the two font OFL notices,
used model/audio/particle licences, the Quaternius acquisition/adaptation README
and the original prop authorship register. The export-filter test checks inclusion
and exclusion for each used notice; unused model packs remain excluded. This
repairs missing notice filters and does not resolve the separate radio provenance
limitation above. Exported-package inspection remains a release check.
