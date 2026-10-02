# Radio: real broadcasts, 1979-86

These are the recordings the car radio (`scripts/game/car_radio.gd`) plays. Every one is a listener's recording of a real
broadcast from the game's years, from a Miami FM or AM station or from a station around the Caribbean, kept on the
Internet Archive; the clips here are re-encoded (mono, 22-32 kHz Vorbis) and cut to a few minutes at most.

## Licence position: read this

**These recordings are not CC0 or MIT like the rest of `assets/`.** The broadcasts themselves (the music, the voices,
the station idents) belong to whoever made them, and the Internet Archive uploads carry no licence we could rely on
(the Archive's own licence field is often missing or wrong on this kind of upload, so it was not trusted). They are
included at the project owner's decision, as short excerpts of period broadcasts for a historical-fiction game, and
under the owner's responsibility. **If you hold the rights to any of them and want one removed, open an issue and it
goes**: delete the folder in `assets/radio/<station>/` and its line in `dial.json` (the dial and the tests adapt).
The rest of the game does not depend on them.

This is also the one place the game uses real station names: the CLAUDE.md rule that content stays fictional covers
the game's own writing, not these recordings.

## Your own stations

Put audio (`.ogg`, `.mp3`, 16-bit `.wav`) in a folder under `user://radio/` (on Windows `%APPDATA%/Godot/app_userdata/Skyrunner/radio/<station>/`) and the car radio finds it: a folder is a station, loose
files in `radio/` are "My tapes". An optional `station.json` in the folder names it:
`{"name": "Miami Nights", "band": "FM", "label": "99.9", "gap_s": 0}`. Nothing in `user://` is ever part of the repo.

## What is here

| Dial | Station | Clip | File | Length | Internet Archive item |
|---|---|---|---|---|---|
| FM 96 | Disco 96 (WMJX) Miami | Late evening, 21 Jan 1979 | `disco96/01.ogg` | 6:00 | [wmjx-disco-96-1-21-79-late-evening-unscoped](https://archive.org/details/wmjx-disco-96-1-21-79-late-evening-unscoped) |
| FM 100.7 | Y100 (WHYI) Miami | Legal ID, April 1985 | `y100/01.ogg` | 0:13 | [100.7-y-100-whyi-fm-miami-florida-legal-id-1985](https://archive.org/details/100.7-y-100-whyi-fm-miami-florida-legal-id-1985) |
| FM 100.7 | Y100 (WHYI) Miami | Weather and the Mega-Station bumper, April 1985 | `y100/02.ogg` | 0:16 | [100.7-whyi-y-100-miami-fl-weather-floridas-mega-station-bumper-april-1985](https://archive.org/details/100.7-whyi-y-100-miami-fl-weather-floridas-mega-station-bumper-april-1985) |
| AM 610 | WIOD Miami | Stu Goldstein, WIOD | `wiod/01.ogg` | 6:00 | [stu-goldstein-wiod-1986-unscoped](https://archive.org/details/stu-goldstein-wiod-1986-unscoped) |
| AM 720 | RJR Jamaica | RJR 720, 22 Dec 1985 | `rjr/01.ogg` | 2:30 | [1985-12-22-jamaica-rjr-720-0014-utc](https://archive.org/details/1985-12-22-jamaica-rjr-720-0014-utc) |
| AM 870 | Mar Caribe, Colombia | Mar Caribe 870, 30 Dec 1984 | `mar_caribe/01.ogg` | 0:16 | [1984-12-30-colombia-mar-caribe-am-870-0247-utc](https://archive.org/details/1984-12-30-colombia-mar-caribe-am-870-0247-utc) |
| AM 1100 | Radio ZDK, Antigua | ZDK 1100, 3 Nov 1983 | `zdk/01.ogg` | 1:48 | [1983-11-03-antigua-radio-zdk-1100-2253-utc](https://archive.org/details/1983-11-03-antigua-radio-zdk-1100-2253-utc) |
| AM 1570 | Atlantic Beacon, Turks & Caicos | Atlantic Beacon 1570, sign-off, 28 Nov 1986 | `atlantic_beacon/01.ogg` | 1:50 | [1986-11-28-turks-and-caicos-islands-atlantic-beacon-1570-0531-utc-s-off](https://archive.org/details/1986-11-28-turks-and-caicos-islands-atlantic-beacon-1570-0531-utc-s-off) |
| SW 3285 | Radio Belize | Radio Belize 3285, 16 Feb 1980 | `belize/01.ogg` | 0:34 | [1980-02-16-belize-r-belize-3285-1200-utc](https://archive.org/details/1980-02-16-belize-r-belize-3285-1200-utc) |
| SW 4930 | 4VEH, Haiti | 4VEH 4930, 1 Dec 1983 | `4veh/01.ogg` | 0:46 | [1983-12-01-haiti-4-veh-4930-2300-utc](https://archive.org/details/1983-12-01-haiti-4-veh-4930-2300-utc) |
| SW 4965 | Radio Landia, Honduras | Radio Landia 4965, 16 Dec 1983 | `honduras_landia/01.ogg` | 0:46 | [1983-12-16-honduras-r-landia-4965-0358-0336-utc](https://archive.org/details/1983-12-16-honduras-r-landia-4965-0358-0336-utc) |
| SW 5950 | La Voz de Nicaragua | La Voz de Nicaragua 5950, 5 Jul 1983 | `voz_nicaragua/01.ogg` | 2:18 | [1983-07-05-nicaragua-la-voz-de-nicaragua-5950-1053-utc](https://archive.org/details/1983-07-05-nicaragua-la-voz-de-nicaragua-5950-1053-utc) |
| SW 5955 | Radio Antilles | Radio Antilles 5955, 2 Apr 1986 | `antilles/01.ogg` | 0:17 | [1986-04-02-dominican-republic-r-antilles-5955-5-1012-utc](https://archive.org/details/1986-04-02-dominican-republic-r-antilles-5955-5-1012-utc) |
| SW 6045 | Radio Santiago, Dominican Republic | Radio Santiago 6045, 13 Feb 1984 | `santiago/01.ogg` | 1:09 | [1984-02-13-dominican-republic-r-santiago-6045-2347-2337-utc](https://archive.org/details/1984-02-13-dominican-republic-r-santiago-6045-2347-2337-utc) |
| SW 6150 | Radio Impacto, Costa Rica | Radio Impacto 6150, 13 Jun 1983 | `impacto/01.ogg` | 1:01 | [1983-06-13-costa-rica-r-impacto-6150-0300-utc](https://archive.org/details/1983-06-13-costa-rica-r-impacto-6150-0300-utc) |
| SW 6200 | Radio Sandino, Nicaragua | Radio Sandino, 25 Mar 1984 | `sandino/01.ogg` | 6:00 | [radio-sandino-nicaragua-25-march-1984](https://archive.org/details/radio-sandino-nicaragua-25-march-1984) |
| SW 6220 | Radio Discovery, Dominican Republic | Radio Discovery 6220, 9 Apr 1986 | `discovery/01.ogg` | 0:53 | [1986-04-09-dominican-republic-r-discovery-6220-0112-utc](https://archive.org/details/1986-04-09-dominican-republic-r-discovery-6220-0112-utc) |
| SW 6990 | Radio Cuba Libre (exile) | Radio Cuba Libre 6990, 22 Jun 1981 | `cuba_libre/01.ogg` | 1:15 | [1981-06-22-clandestine-r-cuba-libre-6990-0330-utc-s-off](https://archive.org/details/1981-06-22-clandestine-r-cuba-libre-6990-0330-utc-s-off) |
| SW 7315 | Radio Sandino, 1979 (clandestine) | Radio Sandino 7315, 16 Jul 1979 | `sandino_1979/01.ogg` | 2:20 | [1979-07-16-clandestine-r-sandino-7315-0401-utc-s-on](https://archive.org/details/1979-07-16-clandestine-r-sandino-7315-0401-utc-s-on) |
| SW 7355 | La Voz de Cuba Independiente y Democratica | La Voz de Cuba Independiente y Democratica 7355, 21 Oct 1981 | `voz_cuba/01.ogg` | 2:47 | [1981-10-21-clandestine-la-voz-de-cuba-independente-y-democratica-7355-0116-utc](https://archive.org/details/1981-10-21-clandestine-la-voz-de-cuba-independente-y-democratica-7355-0116-utc) |
| SW 11815 | Radio Marti | Radio Marti 11815, 3 Jun 1985 | `marti/01.ogg` | 1:17 | [1985-06-03-usa-r-marti-11815-1600-utc](https://archive.org/details/1985-06-03-usa-r-marti-11815-1600-utc) |
| SW 11815 | Radio Marti | WCCO report on the start of Radio Marti, May 1985 | `marti/02.ogg` | 2:30 | [wcco-am-radio-marti-10-and-11-may-1985-.-830-mhz](https://archive.org/details/wcco-am-radio-marti-10-and-11-may-1985-.-830-mhz) |

The Caribbean and Central American shortwave and AM clips are from Dave J. Valko's logs of stations heard in those
years; the Miami and Radio Marti clips are from other listeners' airchecks (the Archive items name each uploader).

Stations are always on air: where a station is in its programme is a function of the game clock, so tuning away and
back finds it further along. Short recordings play, then static, then play again.
