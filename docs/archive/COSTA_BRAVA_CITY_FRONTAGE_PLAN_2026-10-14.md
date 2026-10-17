# Costa Brava city frontage implementation plan

Design: [Costa Brava city frontage and street life](../specs/2026-10-14-costa-brava-city-frontage-design.md)

## Scope

One presentation-only addition to `CityDress`: attach a small, deterministic selection of existing commercial-kit awnings to low-rise shop lots. Preserve existing map data, collisions, simulation, access and performance patterns. Leave the shared building scripts touched by #374 alone.

## Steps

1. Inspect the current shop-lot transform and model-loading path; use the same deterministic lot records rather than creating a second parcel classifier.
2. Add an awning placement helper that filters low-rise shops and downtown landmark indices, makes a stable local RNG decision per lot, aligns the canopy to the street-facing building facade, and uses the standard/wide awning mesh that best fits the frontage.
3. Batch the instances by mesh within the current building chunk. Preserve the existing model visibility range, fade and quality-dependent shadow settings. Do not add collision or interaction nodes.
4. Review the diff for geometry, RNG, material and scene-lifecycle risks. Run the focused presentation lane, import/project-status and documentation checks if the branch environment permits, then capture the city for visual review.
5. Update the #373 branch handoff with the exact commit and evidence. Keep the PR a draft and do not merge it.

## Execution method

Native implementation in the existing #373 linked worktree. The #374 branch remains unchanged; `buildings.gd` and `casino_building.gd` are out of scope because both PRs touch them.
