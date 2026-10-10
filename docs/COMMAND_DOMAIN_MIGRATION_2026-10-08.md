# Command-domain separation — 8 October 2026

Issue #95 is a structural continuation of the completed six-layer Session split.
It does not replace that split or move simulation ownership into menus.

All 105 `_cmd_*` handlers move into six stateless domains: air (29), crew (11),
ground (13), trade (23), court (14) and organisation/intelligence (15).
`CommandDomains.handlers()` maps the established string names to static callables.
Session retains permissions, read-only preview revalidation, outcome messages,
tutorial acknowledgement and its public `[ok, message]` contract.

The authoritative Session is passed at invocation. Cached handlers carry no bound
Session arguments, avoiding an ownership cycle or accidental cross-session writes.
Non-command flight/seat/voice helpers remain on Session. Save serialization is
unchanged and does not persist the derived handler registry.

A token comparison of every old/new handler body confirms exact correspondence
after qualifying state/helper references and inherited constants/types. Strings,
validation order, calculations and return values are unchanged. No fixture edits,
new mechanics, routing or balance tuning are part of this change.

Focused checks pass: command domains three, existing commands three, strategic
saves seven, action reviews eight and determinism registry/scanner six. No script
or parse errors occur in these final runs. The new tests cover the entire permitted
command-name surface, unbound handler ownership, isolated mutation across two
sessions and permission rejection before dispatch.

The full suite, network/golden regression, source smoke and current-head CI must
pass before integration. Existing Godot shutdown resource/ObjectDB/PagedAllocator
diagnostics remain separate cleanup limitations; focused passes do not establish
real two-machine acceptance.
