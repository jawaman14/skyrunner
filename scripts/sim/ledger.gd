class_name Ledger
extends RefCounted
## Money as transfers between accounts (docs/EMPIRE_SIMULATION_SPEC.md section 3). F-2 is the wrap: the old money fields (Session.money,
## law_funds, the war chests) keep their values and every change to one is recorded here as a transfer against UNATTRIBUTED, so the
## log is the to-do list for F-3, which replaces each with a named transfer.

const OUTSIDE := "outside:"
const UNATTRIBUTED := "outside:unattributed"
const COALESCE := ["budget"]  ## reasons booked every frame: consecutive rows with the same names merge within COALESCE_S
const COALESCE_S := 60.0
## The closed list of reasons (spec section 3, invariant 3); a transfer with any other is refused. Later F-3 slices add to it.
const REASONS := ["open", "adjust", "purchase", "resale", "fee", "fuel", "repair", "upgrade", "fine", "delivery", "forfeiture", "budget", "wages"]
const TRIM := 1000  ## rows folded into `opening` at a time, so trimming is not a shift of the whole array on every transfer
const LOG_MAX := 20000  ## the oldest rows are folded into `opening` past this, so rebuild() stays exact; F-3 saves both.

var log: Array = []  ## {id, t, from, to, amount, reason, actor, ref}
var balances := {}
var opening := {}  ## balances of the rows trimmed off the front of the log
var _serial := 0


func balance(account: String) -> float:
	return float(balances.get(account, 0.0))


## One debit and one credit. Refused (false) for a non-positive amount, the same account both sides, or a reason not in REASONS.
func transfer(from: String, to: String, amount: float, reason: String, actor := "system", t := 0.0, ref := "") -> bool:
	if amount <= 0.0 or from == to or not reason in REASONS:
		return false
	var last: Dictionary = log[-1] if not log.is_empty() else {}
	if reason in COALESCE and not last.is_empty() and last.from == from and last.to == to and last.reason == reason \
			and last.actor == actor and t - float(last.t) < COALESCE_S:
		last.amount = float(last.amount) + amount  # a per-frame accrual is one row a minute, not sixty a second
		balances[from] = balance(from) - amount
		balances[to] = balance(to) + amount
		return true
	_serial += 1
	log.append({"id": _serial, "t": t, "from": from, "to": to, "amount": amount, "reason": reason, "actor": actor, "ref": ref})
	if log.size() >= LOG_MAX + TRIM:
		for row in log.slice(0, TRIM):
			opening[row.from] = float(opening.get(row.from, 0.0)) - float(row.amount)
			opening[row.to] = float(opening.get(row.to, 0.0)) + float(row.amount)
		log = log.slice(TRIM)
	balances[from] = balance(from) - amount
	balances[to] = balance(to) + amount
	return true


## Move an account to `value` for a change the old code made directly: the difference is booked against UNATTRIBUTED.
## `other`, `reason` and `actor` name the change (F-3); left alone it is the unattributed adjustment F-2 booked.
## An account seen for the first time opens at `old` (what it held before this change) from outside:start.
func track(account: String, old: float, value: float, t := 0.0, other := UNATTRIBUTED, reason := "adjust", actor := "system") -> void:
	if not balances.has(account):
		balances[account] = 0.0
		opening[account] = 0.0  # so rebuild() lists the account even if nothing has moved yet
		if old > 0.0:
			transfer("outside:start", account, old, "open", "system", t)
		elif old < 0.0:
			transfer(account, "outside:start", -old, "open", "system", t)
	var d := value - balance(account)
	if d > 0.0:
		transfer(other, account, d, reason, actor, t)
	elif d < 0.0:
		transfer(account, other, -d, reason, actor, t)


func total() -> float:
	var sum := 0.0
	for a in balances:
		sum += balance(a)
	return sum


## What the cache should equal: the opening balances plus the rows still in the log.
func rebuild() -> Dictionary:
	var out := opening.duplicate()
	for row in log:
		out[row.from] = float(out.get(row.from, 0.0)) - float(row.amount)
		out[row.to] = float(out.get(row.to, 0.0)) + float(row.amount)
	return out


## Net flow across the boundary: each outside:* account's balance, negated (money that came into the map is positive).
func boundary() -> Dictionary:
	var out := {}
	for a in balances:
		if str(a).begins_with(OUTSIDE):
			out[a] = -balance(a)
	return out


## A loaded save holds `value` in `account`: book the difference as an opening from outside:start, not as an economic event.
func restate(account: String, value: float, t := 0.0) -> void:
	if not balances.has(account):
		track(account, 0.0, 0.0, t)
	var d := value - balance(account)
	if d > 0.0:
		transfer("outside:start", account, d, "open", "system", t)
	elif d < 0.0:
		transfer(account, "outside:start", -d, "open", "system", t)


## Accounts that are below zero and may not be: only outside:* and an org's main account (<org>:safe) may owe. A war chest too, because
## upkeep and fuel debit it unconditionally today (spec invariant 2: unconditional costs keep working).
func overdrawn() -> Array:
	var bad := []
	for a in balances:
		var s := str(a)
		if balance(s) < -0.005 and not s.begins_with(OUTSIDE) and not s.ends_with(":safe") and not s.ends_with(":war-chest"):
			bad.append(s)
	return bad
