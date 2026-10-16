# Skyrunner — 1979–1982 Asset Bible

## Purpose

This document defines the visual and technical target for Skyrunner's world assets. The goal is a coherent late-1970s/early-1980s tropical/coastal smuggling world, not photorealism and not a generic modern city with retro colours.

The art pass should make the simulation legible and believable without becoming an asset-production project larger than the game.

## 1. Visual identity

Target:
- Mediterranean/Costa Brava coastal architecture
- poorer rural settlements and small towns
- airstrips, docks, warehouses, garages and bars
- tropical/subtropical vegetation
- ageing cars and utility vehicles
- analogue infrastructure and early-1980s aviation

Preferred style:
- low-poly 3D
- restrained textures
- strong silhouettes
- simple materials
- weathering carried by geometry, colour and a small number of decals/textures

Initial budgets:

| Asset | Target |
|---|---:|
| Normal vehicle | 1,500–8,000 tris |
| Hero vehicle | 8,000–15,000 tris |
| Background vehicle | 500–2,000 tris |
| Building | 500–5,000 tris |
| Small prop | 20–500 tris |
| Character | 1,500–5,000 tris |
| Main texture | 256²–1024² |
| Small prop texture | 64²–256² |
| Normal vehicle texture | 512² |
| Hero vehicle texture | 1024² maximum |

Prefer one material per simple asset and keep material counts low. Normal maps and heavy PBR are generally unnecessary.

## 2. Visual layers

### Strategic map

2D/isometric or simplified 3D. Prioritise information clarity.

Required visual categories:
- airfield
- stash house
- HQ
- police station
- checkpoint
- dock
- warehouse
- bar
- garage
- safehouse
- race location
- town/city
- fuel station
- court/prison

Every strategic icon should support at least:
- normal
- selected
- danger
- unknown
- friendly
- enemy
- investigated
- inactive

### Walking world

Full 3D for people, vehicles, houses, warehouses, police, garages, shops, docks, airfields, stash locations, roads and physical workers.

### Cockpit/aircraft

Highest visual priority because the aircraft is a core gameplay object. Use period analogue instrumentation and avoid modern avionics aesthetics.

## 3. Period rules

Every asset must plausibly belong in 1979–1982.

Avoid:
- modern SUVs
- LED light bars/signage
- modern road furniture
- smartphones
- flat-screen displays
- modern laptops
- modern traffic barriers
- modern petrol stations
- modern aircraft instrumentation
- modern advertising/signage

Period cues should come from:
- cars
- telephone poles
- analogue signage
- old street lamps
- concrete/stucco houses
- corrugated roofs
- older advertising
- period petrol stations
- docks
- tropical vegetation
- weathering

## 4. Colour and materials

Preferred palette:
- sun-bleached concrete
- dirty white
- cream
- ochre
- faded terracotta
- dusty brown
- weathered grey
- faded blue
- muted green
- dark wood
- rust

Vehicle colours:
- cream
- beige
- brown
- dark green
- navy
- burgundy
- orange
- yellow
- white
- faded blue
- grey
- black

Materials:
- rough plaster
- cracked/chipped concrete
- sun-bleached timber
- corrugated metal
- rusted steel
- simple glass
- patched asphalt
- dirt road shoulders

## 5. Vehicle set

Do not create dozens of unique cars. Start with approximately ten reusable base vehicles and produce colour, condition and role variants.

### Civilian

- V01 1970s American sedan
- V02 1980s compact sedan
- V03 station wagon
- V04 pickup
- V05 panel van
- V06 utility truck
- V07 taxi
- V08 motorcycle
- V09 bus
- V10 boat

### Police

- P01 marked police sedan
- P02 police station wagon
- P03 police pickup/4x4
- P04 unmarked sedan
- P05 Coast Guard boat

Police vehicles should have period light bars, antennas, simple markings, analogue radios and period wheels.

### Vehicle condition

Use one authoritative vehicle entity with visual variants:
- pristine
- worn
- damaged
- wrecked

Damage can be represented by missing/dented panels, broken glass/lights, damaged paint, rust and smoke rather than separate full models.

### Vehicle technical target

Normal:
- 1,500–5,000 tris
- 512² texture
- 1 material where practical
- simple collision
- LOD0/LOD1/LOD2

Hero:
- 5,000–10,000 tris
- 512² or 1024²
- 1–3 materials
- separate wheels
- damage sockets/interchangeable parts where gameplay needs them

Background:
- 500–1,500 tris
- 128²–256²
- simple collision

## 6. Building set

Start with approximately fifteen archetypes.

### Residential
- B01 poor wooden house
- B02 small concrete bungalow
- B03 large villa
- B04 two-storey townhouse
- B05 rural shack

### Commercial
- B06 roadside shop
- B07 bar
- B08 garage
- B09 petrol station
- B10 warehouse
- B11 dock warehouse
- B12 small motel

### Government/operations
- B13 police station
- B14 airfield building/hangar
- B15 Coast Guard building

## 7. Modular architecture

Buildings should be assembled from reusable pieces instead of individually modelling every structure.

Kit:
- walls
- windows
- doors
- roofs
- floors
- balconies
- stairs
- columns
- porches
- fences
- garages
- awnings
- shutters

Custom Skyrunner architecture should emphasise:
- stucco/concrete
- corrugated roofs
- timber
- shutters/louvres
- security bars
- verandas
- external stairs
- water tanks
- rooftop radio/communications equipment

Generic modular kits can be used for prototyping, but the final world should not look like an unmodified third-party asset pack.

## 8. Roads and infrastructure

Road kit:
- straight road
- corner
- T junction
- crossroad
- bridge
- dirt road
- parking area
- airfield road
- dock road
- mountain road

Roadside kit:
- telephone pole
- power pole
- transformer
- street lamp
- road sign
- advertising sign
- guard rail
- concrete barrier
- fence
- ditch/drain

Period infrastructure is more valuable than large quantities of decorative props.

## 9. Props

Initial reusable target: 40–60 props.

Priority:
1. wooden crate
2. cardboard box
3. oil drum
4. fuel drum
5. pallet
6. toolbox
7. tyre
8. spare wheel
9. generator
10. welding equipment
11. workbench
12. chair
13. table
14. bench
15. rubbish bin
16. dumpster
17. chain-link fence
18. wooden fence
19. concrete fence
20. road barrier
21. traffic cone
22. street sign
23. telephone pole
24. transformer
25. street lamp
26. water tank
27. fuel tank
28. boat trailer
29. fishing net
30. rope coil
31. barrel
32. hand truck
33. forklift
34. luggage
35. radio
36. payphone
37. TV
38. refrigerator
39. cassette player
40. desk telephone

## 10. Period technology

Useful environmental props:
- CRT television
- rotary telephone
- early push-button telephone
- cassette deck
- portable cassette player
- analogue radio
- VHF radio
- radar display
- CRT computer terminal
- dot-matrix printer
- paper charts
- filing cabinet
- calculator
- typewriter

Do not use modern electronics as filler.

## 11. Aircraft

Keep the fleet small and readable.

Required categories:
- A01 small single-engine bush plane
- A02 C182-class aircraft
- A03 faster single-engine aircraft
- A04 twin-engine aircraft
- A05 specialised smuggling aircraft

Aircraft visuals should expose the existing authoritative state where applicable:
- fuel
- payload
- crew
- damage
- engine state
- landing gear
- lights
- navigation
- radio

Cockpits should use analogue gauges, magnetic compass, period radio/transponder and appropriate switches.

## 12. Airfields

Required:
- runway
- runway markings
- taxiway
- hangar
- windsock
- fuel tank/pump
- maintenance shed
- office
- tool shed
- fence
- gate
- lights
- radio antenna
- parking apron

Mountain strips should have dirt, rocks, vegetation, uneven terrain and minimal infrastructure.

## 13. Docks

Required:
- wooden dock
- concrete dock
- pier
- boat ramp
- small warehouse
- fuel tank
- crane
- cargo crates
- barrels
- rope
- nets
- fishing boat
- smuggling boat
- Coast Guard boat

## 14. Vegetation

Use period/location-appropriate subtropical/coastal vegetation:
- palms
- scrub
- dry grass
- bushes
- coastal grasses
- olive-like trees
- eucalyptus-like trees
- tropical trees
- vines
- weeds
- reeds

Use three levels:
- hero vegetation
- normal vegetation
- background billboard/card vegetation

## 15. Characters

Create a small set of reusable base bodies rather than hundreds of unique models.

Base targets:
- male
- female
- larger male
- smaller male
- larger female

Variants should come from clothing, hair, hats, uniforms and accessories.

Roles:
- pilot
- mechanic
- driver
- dealer
- dock worker
- farmer
- shopkeeper
- police
- detective
- military
- Coast Guard
- bartender
- civilian
- criminal
- informant

Clothing should be period appropriate: jeans, work shirts, T-shirts, polos, jackets, boots, sneakers, sandals, leather jackets, dark shirts, overalls and period police uniforms.

## 16. Simulation-driven visual states

Visuals must derive from authoritative simulation state. UI/rendering must not create a second authority.

Radar:
- unknown contact
- friendly
- civilian
- suspected
- confirmed
- police
- aircraft
- boat

Intelligence:
- rumour
- unconfirmed
- probable
- confirmed
- stale
- recent
- false

Police:
- patrol
- search
- checkpoint
- intercept
- investigation
- known target
- arrest

Uncertainty must remain visible; the player should not receive information their role does not know.

## 17. Asset naming

Use predictable names such as:
- veh_sedan_80_a
- veh_pickup_80_a
- veh_police_sedan_80_a
- bld_house_concrete_small_a
- bld_house_wood_small_a
- bld_bar_coastal_a
- bld_warehouse_small_a
- prop_crate_wood_a
- prop_barrel_oil_a
- prop_phone_wall_a
- veg_palm_a
- char_police_male_a
- char_mechanic_male_a

Avoid names such as car_final2_new.blend, asset123.glb or newcar2.png.

## 18. Repository structure

Preferred:
    assets/
        world/
            buildings/
            vehicles/
            props/
            vegetation/
            roads/
            docks/
            airfields/
        characters/
            civilian/
            police/
            crew/
            criminals/
        aircraft/
            c182/
            single_engine/
            twin_engine/
        strategic/
            buildings/
            vehicles/
            icons/
            overlays/
        ui/
            icons/
            markers/
            maps/
        audio/
            vehicles/
            environment/
            radio/

## 19. Provenance and licensing

Create and maintain:
    docs/ASSET_PROVENANCE.md

Each external asset must record:
- asset name
- source
- author
- URL
- licence
- attribution requirement
- commercial-use status
- modification permission
- redistribution permission
- acquisition date
- where it is used

Licence preference:
1. CC0
2. CC BY
3. other clearly permissive commercial licence after review
4. unknown licence — reject
5. restrictive/unclear/no-AI/non-commercial/redistribution-restricted asset — reject unless explicitly cleared

Do not bulk-import entire asset packs. Import only assets actually used.

## 20. Initial vertical slice

Before populating the entire world, build one complete Costa Brava test town:
- 1 small airfield
- 1 coastal road
- 1 small town
- 5 houses
- 1 bar
- 1 garage
- 1 warehouse
- 1 police station
- 1 dock
- 1 petrol station
- 10 civilian vehicles
- 2 police vehicles
- 1 boat
- 10 NPCs
- 20 props
- 10 vegetation assets

The slice must be tested in the exported game, not only the Godot editor.

## 21. Initial production target

| Category | Initial target |
|---|---:|
| Cars | 10 |
| Police vehicles | 2–3 |
| Trucks/vans | 4 |
| Boats | 3 |
| Aircraft | existing + 2–3 |
| Houses | 5 |
| Commercial buildings | 5 |
| Government buildings | 3 |
| Industrial buildings | 3 |
| Props | 40 |
| Vegetation | 15 |
| Character base variants | 10 |
| Strategic icons | 25–30 |

## 22. External asset policy

Prefer CC0 sources and keep provenance in-repo.

Useful starting sources:
- Kenney RPG Urban Kit
- Kenney Retro Urban Kit
- Kenney Building Kit
- Kenney Car Kit
- OpenGameArt low-poly vehicle packs
- OpenGameArt PSX-style vehicle packs

These are starting points and references, not a requirement to retain their unmodified visual style.

## 23. Claude implementation rules

1. Never commit an external asset without provenance.
2. Never introduce an asset with an unknown licence.
3. Prefer CC0 assets.
4. Do not bulk-import asset packs.
5. Import only assets actually used.
6. Optimise assets before committing.
7. Maintain consistent scale and origins.
8. Maintain consistent collision conventions.
9. Use LODs for large world assets.
10. Do not duplicate assets under different names.
11. Do not embed authoritative gameplay state in visual assets.
12. Visual variants must consume the same simulation entity.
13. Vehicle visual state must derive from authoritative vehicle state.
14. Use modular assets instead of individually modelling every building.
15. Test assets in the exported game, not only the editor.
16. Check draw calls and memory after each asset batch.
17. Record licence/provenance when an asset is imported.
18. Keep the art style consistent across sources.
19. Do not use asset acquisition as a substitute for gameplay implementation.
20. Any asset that materially changes the game's visual identity should be reviewed against this bible before being added.

## 24. Core art principle

The asset pass exists to make the simulation legible and believable.

A police checkpoint should look like a police checkpoint.
A stash house should look like somewhere something could be hidden.
A cargo run should visibly involve vehicles, cargo and people.
An airfield should look operational.
A damaged vehicle should look damaged.
A 1981 town should look unmistakably like 1981.

The preferred result is a relatively small number of highly reusable assets that make every important simulation system visible in the world.
