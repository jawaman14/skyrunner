# Human release gates: scripts for the person who runs them

These are the checks no agent can pass: they need a person, a real device or a rights decision. Each script says what to run,
what to do, what you should see, and what to bring back. **Nothing here is a result.** Record each outcome as a row (pass, fail or
blocked, date, build, your name) in the register in [PROJECT_STATUS.md](PROJECT_STATUS.md) and attach the evidence; an agent may
copy your row in, but may not mark a gate passed. Source of the gate list: [ROADMAP.md](ROADMAP.md) "Completion gates" and the
"Unperformed" line in PROJECT_STATUS. The owner's single list is issue #326.

**Which build.** Use the exported build from the CI run for the commit you are testing (the "export" job of the Skyrunner beta
builds workflow produces Linux, Windows and macOS builds). Write the commit's short SHA in every result row. Do not test the editor
and call it the exported build; the gate is about the export.

**Keys you will need.** F8 controls panel (rebinding, the colour palette, read-aloud, screen filter), F4 multiplayer menu, F10 skips
a tutorial step (Shift+F10 turns the tutorial off), M the map. Settings are saved in `user://controls.cfg`.

## G1. Exported Windows walkthrough
Needs: a Windows 10/11 machine without the Godot editor; the Windows export.
1. Unzip, launch the executable. Expect the lobby to open with no console errors and no missing-asset dialogs.
2. Start a new Story game with the tutorial on. Complete the employed opening: four flights, the first aircraft purchase.
3. Quit to the lobby and press Continue. Expect your chapter and money on the Continue button and the save to load where you left it.
4. Open every desk once (jobs, load, hangar, logistics, the phone). Expect each to open and close with the mouse and the keyboard.
Bring back: the commit SHA, the first minute of any error text on screen, a screenshot of the lobby and one of the hangar, and what
felt wrong (confusing, slow, ugly) in your own words.

## G2. macOS exported walkthrough
Same as G1 on a Mac with the macOS export. Extra: the first launch may be blocked by Gatekeeper because the build is unsigned; note
exactly what the dialog says and what you had to do. Result row names the macOS version and the chip.

## G3. Controller, read-aloud and display matrix
Needs: a physical gamepad (and a flight stick if you have one), the Windows export, a display you can set to four sizes.
1. Plug in the controller before launch. In F8, confirm every axis and button you use appears; rebind one button and confirm it holds
   after a restart.
2. Fly one job with the controller only. Expect no stuck axis, a working deadzone, and every menu reachable by controller. Note any
   action that needs the keyboard (the controller B-button cancel is a known open path).
3. For each of 1024x768, 1280x720, 1920x1080 and 2560x1080, and for each palette (the default "neon" and the colour-safe one, chosen in
   F8): open the lobby, the HUD in flight, the jobs desk and the map. Expect nothing clipped or off-screen, text legible,
   and a visible focus outline on whatever the keyboard or controller has selected.
4. Turn read-aloud on in F8. Walk one menu and one tutorial step. Expect each focused control and each tutorial line to be spoken, and
   the voice to stop when you move on.
Bring back: a pass, fail or blocked cell for every size by palette (8 cells), a screenshot per failing cell, and the controller model.
The screenshot matrix PR (#300) captures the machine half; this is the human half.

## G4. Two-machine multiplayer (seat, action and voice)
Needs: two computers on one network, both with the same exported build, a headset or speakers and a microphone each.
1. Machine A: F4, host a game, open remote seats. Machine B: join (LAN first; then by the address if you can).
2. B takes a non-pilot seat (spotter, boat, controller or chief). Expect the seat to be offered, taken, and shown to A.
3. A flies; B performs an action from the desk (an order, a command). Expect it to reach A's game with an acknowledgement, and a refusal
   to be shown if the action is not allowed.
4. Voice: A and B talk. Expect each to hear the other clearly, with no feedback howl. Mute and unmute if the menu offers it.
5. B leaves, then rejoins. Expect the seat to free and be retaken, and no stuck state on A.
Bring back: both machines' OS, the build SHA, whether LAN and address joins worked, round-trip delay you perceived on a command and on
voice, and any error text on either screen.

## G5. Functional-site walk and drive acceptance
Needs: the exported build. The point is that every building you are meant to reach can be reached, and the roads connect.
1. Start an Open game on Costa Brava. For each functional site (loading areas, HQs, the club, hangars, the villa), go on foot to its
   entrance and through it. Expect no invisible wall, no walking through a wall, and a visible threshold.
2. Drive a car along the main roads and across every bridge. Expect no stuck wheel, no vehicle falling through, and no road that
   stops at a building.
3. Note the site and the position wherever a route fails.
Bring back: a list of sites that passed and, for each failure, the site name, what you did and a screenshot.

## G6. Performance captures on fixed routes
There is no capture tool yet, so this gate also needs a harness (open work in #328). Until then: use the same machine and the same
export for both runs, a fixed route (take off from the hub, fly the same circuit in the same weather, then a drive through the
densest town), and record average and worst-1% frame time and the process memory at the start and end. A regression above 10% against
the previous commit is a failure to investigate. Bring back: machine description, the route, the numbers for each run.

## G7. Radio and third-party asset rights (a decision, not a test)
The bundled radio recordings are archived broadcasts sourced from listener recordings; their redistribution rights are unresolved and
they are not CC0 ([ASSET_PROVENANCE.md](ASSET_PROVENANCE.md), issue #175, now in #326). Decide one of: obtain permission or licences,
replace the recordings with cleared or original audio, or ship without the radio. An agent can prepare the replacement or the removal
once you choose; it cannot decide the rights.

## What an agent does for you
Prepare the build and the commit SHA to test, copy your rows into the register with your evidence attached, turn your failure notes
into issues in the agents' queue (#327), and re-run the machine half. It never marks a gate passed on its own.
