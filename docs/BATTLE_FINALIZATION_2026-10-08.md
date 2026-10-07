# External combatant removal - 8 October 2026

Parent is faction AI continuation #244. A direct reproduction on #240 removed
one fighting squad and left its survivor with state fighting, an ended Fight
reference and a completed report saying fighting. Because the fight had already
been erased, future battle rounds could not clear the survivor. This is a live
lifecycle problem as well as a report defect, not just a formatting issue.

GroundWar._gone now uses the existing _end path when an active engagement exists.
That path releases both references, settles a still-fighting survivor to holding
and records accounts after settlement. The removed squad remains gone. Existing
human order ownership is preserved. Repeated late finalization cannot duplicate
accounts. Ammo/weapon returns and casualty/arrest calculations are unchanged;
no new random draws or combat tuning are introduced.

Focused validation: ground 30 passed, foot combat 9 passed, battle save/formatter
2 passed; zero failures and no script/parse errors. Full final-tree regression
and smoke are recorded after completion. Existing shutdown cleanup diagnostics
remain separate. The ten-seed AI comparison belongs to #244, not a dedicated
external-casualty balance measurement or a human battle playtest.

Remaining: casualty versus custody details, tactical explanations, operational
debriefs, physical-member combat migration and real human/two-machine acceptance.
#244's measured AI balance shift still requires wider review. This fix does not
resolve those gates or establish a release-ready main baseline.
