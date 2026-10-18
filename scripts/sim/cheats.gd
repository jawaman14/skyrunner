class_name Cheats
extends RefCounted
## The owner's test menu (Ctrl+F6, solo play only): money, full stash houses, no heat, a full tank. Each action edits the
## session directly, the way a debug key does, and is never a command: nothing here reaches a shared table or a save
## made by a normal game's rules. Add an action by adding a row to ACTIONS and a branch to run().

const FILL_LB := 500.0  ## of each good, per stash house
const FILL_CASH := 25000.0  ## per stash house

const ACTIONS := [
	["money_100k", "Add $100,000", "cash in hand"],
	["money_1m", "Add $1,000,000", "cash in hand"],
	["fill_stashes", "Fill every stash house", "500 lb of each good and $25,000 in each safe"],
	["clear_heat", "Clear all heat", "police, wanted level and every stash's heat and intel"],
	["refuel", "Fill the tank", "the aircraft you are in, wherever it is"],
	["heat_up", "Raise the heat", "wanted level 3 and suspicion 80 on the pilot"],
	["free_workers", "Free caught workers", "everyone in jail walks out now"],
	["next_chapter", "Skip to the next chapter", "the story's debug skip"],
]


## Run one action; returns what happened, for the menu's feedback line.
static func run(s: Session, id: String) -> String:
	match id:
		"money_100k":
			s.money += 100000
			return "Added $100,000."
		"money_1m":
			s.money += 1000000
			return "Added $1,000,000."
		"fill_stashes":
			if s.logistics == null:
				return "This game has no logistics network."
			var n := 0
			for site in s.logistics.stock.keys():
				for g in s.logistics.goods():
					s.logistics.add(site, g, FILL_LB)
				if site != Logistics.HQ:
					s.logistics.add_cash(site, FILL_CASH)
				n += 1
			return "Filled %d stash houses." % n
		"clear_heat":
			s.police.reset(false)
			if s.stash_net != null:
				for st in s.stash_net.stashes:
					st.heat = 0.0
					st.intel = 0.0
			return "Heat cleared."
		"refuel":
			if s.loadout == null or s.fm == null:
				return "No aircraft to fill."
			s.loadout.fuel_lb = s.loadout.mass.fuel_capacity_lb()
			s.fm.apply_loadout(s.loadout)
			return "Tank full."
		"heat_up":
			s.police.suspicion = 80.0
			s.police.wanted = 3
			return "Heat raised."
		"free_workers":
			if s.payroll == null:
				return "This game has no crew."
			var ids: Array = s.payroll.jail.map(func(j): return j.id)
			s.payroll.jail.clear()
			s.payroll.release(ids)
			return "Freed %d workers." % ids.size()
		"next_chapter":
			if s.story == null:
				return "This game has no story."
			s.story.debug_skip_chapter()
			return "Skipped to chapter %d." % s.story.chapter.num
	return "Unknown cheat."
