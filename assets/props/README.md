# Period airfield props

Original SVG artwork authored for Skyrunner, with no external images or fonts.
The source vectors are editable; Godot imports the pump face at 256 square and
the notice sheet at 512 by 256. Both use muted cream, rust, timber and sage.

`analogue_fuel_face.svg` is a decorative mechanical meter, not a live fuel readout.
`pinned_notices.svg` is decorative paper dressing, not authoritative job data.
Actual fuel, jobs and prices remain in the interaction menus.

Buildings places these textures on small shared-material quads. The pump keeps
its existing collision and interaction point; trim and hose are visual details.
No new lights, physics bodies, random draws or simulation state are introduced.
