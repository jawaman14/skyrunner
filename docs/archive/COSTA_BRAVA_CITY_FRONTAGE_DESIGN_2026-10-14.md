# Costa Brava city frontage and street life

## Purpose

Make the walkable commercial parts of San Telmo read as lived-in streets in the game's late-1970s and early-1980s setting. Build on the existing sidewalk, street-furniture, district-colour and building-model work. The city should gain a small amount of recognizable frontage detail without changing its map, building footprints, collision, access, economy, or simulation.

## Design principles

Model-city guidance emphasizes a coherent place and scene: road, building, terrain, weathering and street details should support the same setting. Urban street guidance describes the sidewalk as the interface between storefronts and people, with frontage, a clear walking route, and a furnishing zone. Procedural-city research also treats land use and transport access as inputs to building placement rather than decorating a road grid uniformly.

Applied to Skyrunner:

- Add awnings only to low-rise commercial (`shop`) buildings, where they read as customer-facing frontage.
- Use the existing Kenney City Commercial `detail-awning` and `detail-awning-wide` models. Keep their original asset materials and the game's fictional branding rule.
- Choose placements from a local seeded random stream derived from the stable building and lot indices. Rebuilding the same map produces the same result; no simulation RNG or time reads are introduced.
- Place awnings on the model's street-facing facade and at ground-floor height. Skip towers, warehouses, downtown landmark replacements and buildings outside the existing dressed-model range.
- Batch instances by source mesh and retain the existing visibility-range fade and quality behavior.
- Awnings are visual dressing only: no new collision, interaction, signage claims, economy, ownership, or access rules.

## Existing architecture and scope

`CityDress.lots()` already produces deterministic model instances facing the nearest street. `CityDress.build()` batches these models by kit and name inside 300 m chunks, while the box layer remains for distance and low quality. The frontage dressing will consume those same lot transforms and chunk indices, so it follows the current camera-distance and batching system without changing road or parcel geometry.

The current slice is limited to awnings. Continuous shop rows, population schedules, signage systems, port frontage, new business activity and real-world data ingestion remain separate work. The game remains fictional; source maps and photos guide relationships and composition, not copied named businesses or buildings.

## Acceptance criteria

1. Eligible low-rise shop lots can receive a frontage awning; non-shop, warehouse, tower and landmark lots do not.
2. Placement is deterministic for a fixed input and does not use global RNG.
3. Awnings are batched with the nearby building models and inherit their visibility range and shadow-quality behavior.
4. The visual addition does not add collision or interaction nodes and does not change building footprints or map geometry.
5. Low-quality or disabled CityDress continues to show only the existing building boxes.

## References

- [NMRA scenery guidance](https://www.nmra.org/node/67) — prototype-specific scenes, terrain, roads and small signs of use.
- [NACTO sidewalk design](https://nacto.org/publication/urban-street-design-guide/street-design-elements/sidewalks/sidewalk-design/) and [sidewalk zones](https://nacto.org/publication/urban-street-design-guide/street-design-elements/sidewalks/sidewalk-zones/) — the storefront-to-sidewalk relationship and clear walking/furnishing zones.
- [Procedural modeling of urban layout: population, land use, and road network](https://www.sciencedirect.com/science/article/pii/S235214651730491X) — city form as interacting land-use, population and road layers.
- [OpenStreetMap feature catalogue](https://wiki.openstreetmap.org/wiki/Map_features) — practical vocabulary for classifying streets, buildings, shops, amenities and land use during reference gathering.
