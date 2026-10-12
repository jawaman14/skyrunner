# Presentation layers: fashion, graffiti, city pulse (future, not scheduled)

Owner ideas, 12–13 October 2026, collected here in full. The short list is in [ROADMAP.md](ROADMAP.md).

**Rule for all of it:** read-only presentation. These layers read simulation state; they never change an outcome and never
draw on a simulation RNG stream. The era, the music, the look and the crews all follow one timeline.

## 1. Fashion that follows the era

1. **Wardrobe by year.** Each in-game year has its own clothing set for the walker: shirts, jackets, hair and shoes from
   the early-80s palette. A new item appears in shops in step with the music palette, so the player sees the shift before
   they hear it.
2. **Vehicle and aircraft liveries.** Paint and decal sets change by year. Early years are muted, later years bolder with
   neon trim. Owned aircraft keep their livery, so an older plane looks dated next to a new one.
3. **Club and interior dressing.** Venues update their décor on the same schedule as the music, with posters and screens
   matching the station that plays inside.

## 2. Visuals that represent turf and mechanics

4. **Crew colours and signage.** Each crew has a colour and a motif, shown on vehicles, jackets and building fronts. Taking
   a district repaints its signs over time, so territory is visible on the map and the street.
5. **Heat in the look.** Police heat shows as subtle changes: streetlights flicker, patrol cars are more common, and
   characters wear darker clothes or hoods when hot. Cooling down reverses it gradually.
6. **Reputation and trust.** A trusted crew's colours appear on your clothing or car. Breaking trust strips them back, so
   the player's appearance reflects the relationships.

**Keeping it from jarring**
- Change clothing and paint in the same quiet moments as the music: shop visits, a DJ ident, or a sleep cycle.
- Keep one colour key per crew so a change reads as a shift in allegiance, not a glitch.
- Let the player choose their own look within the year's palette, so the shift is a backdrop, not a takeover.

**Roadmap fit:** this belongs with the territory radio and the crew trust table.

## 3. Graffiti as turf

- Crews tag the streets they hold. Tags show the crew colour and motif, and fresh tags look sharper than faded ones.
- A tag fades when a district changes hands and a rival's tag goes up over it, so the wall shows the history of the fight.
- Clearing a tag (by a crew, or by the city cleaning up after a quiet spell) is a visible sign that the street is calm.

## 4. City pulse: the simulation made audible and visible

**Mapping each system to a signal**
- **Economy:** a rhythm. Money flowing in (stock sold, cash collected) adds a light, bright pulse. Money drying up (wages
  unpaid, stock short) slows the beat and thins the bass.
- **Faction:** a melody that belongs to each faction. A rising faction's motif gets louder and gains a few notes. A
  falling one drops out. Two factions in conflict play their motifs against each other.
- **Turf war:** a contested tone. Districts under dispute get an unresolved interval, which resolves when one side wins.
  Lost ground fades out of the mix.
- **Consequences:** a stinger with a clear direction. A pull (a favour, a bribe paying off, a rival retreating) lifts the
  mix upward. A push (a bust, a lost shipment, a betrayed crew) drops it and adds a dissonant hit.

**Visual side**
- **Map and streets:** territory tinted by faction colour, with a slow shimmer on disputed areas.
- **HUD:** a small "pressure" gauge that leans toward whichever side is gaining, shown as a tilt rather than a number.
- **Weather and light:** tension raises haze or dims the light; prosperity brightens the street and adds lit windows.

**Keeping it readable**
- Only the biggest changes trigger a stinger, so the player is not flooded.
- Each signal has a name and a legend in the pause menu, so the player learns the language.
- Changes ease in over several seconds, matching the era-shift rule.

**Roadmap fit:** build it after the territory radio. The radio and the crew-trust table supply the first inputs, and the
rest of the systems can plug in one at a time.

## 5. Territory radio and era music (from earlier)

See [ROADMAP.md](ROADMAP.md): stations per crew, era music in stems with the same key and tempo, changes only at natural
breaks, original fictional tracks only.

## Decisions from the owner (13 October 2026)

1. **Stinger:** a one-to-three-second musical sting marking a single event. Punctuation, not a change of track.
2. **Player faction:** the player chooses their own colours and tag. AI factions get stakeholder designs so the player can
   read who is who at a glance.
3. **Zones:** a zone is yours only after you win it, and then you must graffiti it to claim it. The graffiti is a visual
   indicator of ownership, added by the player, not an automatic change.
4. **Dynamic between systems:** the economy, factions and turf war react to each other, not as separate signals.
5. **Per year, per station:** the music and look are accurate to each year. New genres bring new stations, and a genre
   that takes over a station replaces the one it displaces. A playlist of tracks for these is being collated for the
   owner's own use, kept under `user://radio` and never in the repository.
6. **Scope:** future roadmap, not scheduled.
7. **Wordless:** the pulse never states its meaning in words. The player learns it from the pause-menu legend.

## Follow-up decisions (13 October 2026)

- **Zone takeover:** a rival's graffiti spreads over a zone slowly, and the player's graffiti fades as it does. Ownership
  is a gradual change, not a switch.
- **Genre stations:** the playlist for the genre stations is being finished by the owner's ChatGPT, then used as the
  station content for each year. The arc of genres follows the playlist, not a fixed list in the game.
