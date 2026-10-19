class_name Ledger
extends RefCounted
## Money as transfers between accounts (docs/EMPIRE_SIMULATION_SPEC.md section 3). F-2 is the wrap: the old money fields (Session.money,
## law_funds, the war chests) keep their values and every change to one is recorded here as a transfer against UNATTRIBUTED, so the
## log is the to-do list for F-3, which replaces each with a named transfer.

const OUTSIDE := "outside:"
const UNATTRIBUTED := "outside:unattributed"
const LOG_MAX := 20000  ## shortcut: the oldest rows are dropped past this, so rebuild() is only exact while `dropped` is 0; F-3 saves the log.

var log: Array = []  ## {id, t, from, to, amount, reason, actor, ref}
var balances := {}
var dropped := 0
var _serial := 0


func balance(account: String) -> float:
	return float(balances.get(account, 0.0))


## One debit and one credit. Refused (false) for a non-positive amount, the same account both sides, or no reason.
func transfer(from: String, to: String, amount: float, reason: String, actor := "system", t := 0.0, ref := "") -> bool:
	if amount <= 0.0 or from == to or reason == "":
		return false
	_serial += 1
	log.append({"id": _serial, "t": t, "from": from, "to": to, "amount": amount, "reason": reason, "actor": actor, "ref": ref})
	if log.size() > LOG_MAX:
		log.pop_front()
		dropped += 1
	balances[from] = balance(from) - amount
	balances[to] = balance(to) + amount
	return true


## Move an account to `value` for a change the old code made directly: the difference is booked against UNATTRIBUTED.
## An account seen for the first time opens at `old` (what it held before this change) from outside:start.
func track(account: String, old: float, value: float, t := 0.0) -> void:
	if not balances.has(account):
		balances[account] = 0.0
		if old > 0.0:
			transfer("outside:start", account, old, "open", "system", t)
		elif old < 0.0:
			transfer(account, "outside:start", -old, "open", "system", t)
	var d := value - balance(account)
	if d > 0.0:
		transfer(UNATTRIBUTED, account, d, "adjust", "system", t)
	elif d < 0.0:
		transfer(account, UNATTRIBUTED, -d, "adjust", "system", t)


func total() -> float:
	var sum := 0.0
	for a in balances:
		sum += balance(a)
	return sum


## What the cache should equal: the balances rebuilt from the log (exact only while nothing was dropped).
func rebuild() -> Dictionary:
	var out := {}
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


## Accounts that are below zero and may not be: only outside:* and an org's main account (<org>:safe) may owe.
func overdrawn() -> Array:
	var bad := []
	for a in balances:
		var s := str(a)
		if balance(s) < -0.005 and not s.begins_with(OUTSIDE) and not s.ends_with(":safe"):
			bad.append(s)
	return bad
