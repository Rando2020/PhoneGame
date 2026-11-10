class_name PegSession
extends RefCounted
## The Play as the web UI runs it, without drawing: doCribCount's afterCount
## test, showPegging's setup, pegLay's turn hand-off and renderPegging's payout.
## The rules live in PegPlay (proven against the JS); this holds only what the
## web keeps in its UI code, so it can be tested against fixture group playui.

var rd: CribRound
var play: PegPlay
var opp: Array = []
var mult := 1.0          ## the play rides the count's multiplier, at least x1
var applied := false


## afterCount: the Play happens only with the system owned and 4+ cards left.
static func wanted(round_: CribRound) -> bool:
	return Achv.has_system("the_play") and round_.stock.size() >= 4


## showPegging: the Spoiler's four come off the FRONT of the stock (the
## starter comes off the back), so this changes what the round deals next.
static func start(round_: CribRound, kept: Array) -> PegSession:
	var s := PegSession.new()
	s.rd = round_
	for i in 4:
		s.opp.append(round_.stock.pop_front())
	s.play = PegPlay.new(round_, kept, s.opp)
	# Math.max(1, (rd.lastCount && rd.lastCount.mult) || 1)
	var lc = round_.last_count
	var m = JS.or_(lc, "mult", 1) if lc != null else 1
	s.mult = maxf(1.0, float(m))
	s.play.step()
	return s


## pegLay: the player's card, then the Spoiler is due. Returns points scored.
func lay(i: int) -> int:
	var gained := play.lay("you", play.mine[i])
	play.turn = "them"
	return gained


## The Spoiler's answer (the web waits a beat before this).
func answer() -> void:
	play.step()


func playable_indices() -> Array:
	var out := []
	for i in play.mine.size():
		if play.playable(i):
			out.append(i)
	return out


## The Spoiler's pegging eats into yours: half of theirs, rounded down.
func net() -> int:
	return maxi(0, play.score - int(floor(play.opp_score / 2.0)))


func gain() -> int:
	return JS.round_(net() * mult)


## CONTINUE: the gain joins the round score, once.
func apply() -> int:
	if applied:
		return 0
	applied = true
	var g := gain()
	rd.score += g
	return g
