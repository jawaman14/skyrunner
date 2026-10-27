class_name Affinity
extends RefCounted
## Relationship kind roll table and its gameplay effects, so every consumer shares one threshold and payoff map.

const HATE := "hate"
const FRIEND := "friend"
const LOVE := "love"
const NONE := "none"

## Map a uniform 0..1 roll to a kind; the caller supplies r, this class draws no randomness.
static func roll(r: float) -> String:
	if r < 0.10:
		return HATE
	if r < 0.30:
		return FRIEND
	if r < 0.35:
		return LOVE
	return NONE


## Pay multiplier for crew work given a relationship kind.
static func pay_mult(kind: String) -> float:
	match kind:
		HATE:
			return 0.90
		FRIEND:
			return 1.05
		LOVE:
			return 1.10
		_:
			return 1.0


## Whether the pair refuses to take a crew job together; only HATE refuses.
static func refuses_together(kind: String) -> bool:
	return kind == HATE


## Loyalty points the partner loses when their counterpart is arrested.
static func partner_loyalty_drop(kind: String) -> float:
	match kind:
		LOVE:
			return 15.0
		FRIEND:
			return 5.0
		_:
			return 0.0


## Player-facing line for a relationship, naming the other actor.
static func label(kind: String, other: String) -> String:
	match kind:
		HATE:
			return "Hates %s: will not work a crew job with them." % other
		FRIEND:
			return "Friends with %s: steadier together." % other
		LOVE:
			return "Loves %s: will not betray them." % other
		_:
			return ""
