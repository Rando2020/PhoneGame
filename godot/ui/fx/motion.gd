class_name Motion
extends RefCounted
## Building-and-collecting motion (pass 21). One rule makes every animation
## safe: the screen draws its FINAL state first, then an animation runs from a
## temporary start toward it. Each job carries a `finish` callable that puts
## its nodes back in that final state, so skip() (a tap) kills every tween and
## lands exactly on what a static draw shows. Presentation only.
##
## Tweens are created on the animated node itself (they die with it: no
## SceneTreeTimer, no await). Motion.enabled = false draws everything at rest
## (tests compare against it). MeldSprite.reduce_motion swaps movement for a
## short cross-fade.

static var enabled := true

const SPRING := 0.35          ## response for flights and settles (Apple: 0.3 to 0.4 s)
const FADE := 0.2             ## Reduce Motion's cross-fade

var jobs: Array = []          ## [{tween, finish}]


static func on() -> bool:
	return enabled


static func reduced() -> bool:
	return MeldSprite.reduce_motion


## Track a tween and how to finish it. The tween ends by calling finish too.
func add(tw: Tween, finish: Callable) -> void:
	var job := {"tween": tw, "finish": finish, "done": false}
	jobs.append(job)
	tw.finished.connect(func(): _end(job))


func _end(job: Dictionary) -> void:
	if job.done:
		return
	job.done = true
	if job.finish.is_valid():
		job.finish.call()
	# let go of it: the job held the tween and the tween's signal held the job,
	# a cycle that kept every finished animation alive (screen_leak_test)
	job.tween = null
	job.finish = Callable()
	jobs.erase(job)


func running() -> bool:
	for j in jobs:
		if not j.done:
			return true
	return false


## Finish everything now, at rest. Safe any number of times.
func skip() -> void:
	for j in jobs.duplicate():
		if j.done:
			continue
		if j.tween != null and j.tween.is_valid():
			j.tween.kill()
		_end(j)


## A cross-fade in (Reduce Motion's stand-in for movement): alpha 0 -> rest.
func fade_in(n: CanvasItem) -> void:
	var rest := n.modulate
	n.modulate = Color(rest, 0.0)
	var tw := n.create_tween()
	tw.tween_property(n, "modulate", rest, FADE)
	add(tw, func(): if is_instance_valid(n): n.modulate = rest)


## A settle: scale from `from` back to 1 with a light spring (pivot at centre).
func settle(n: Control, from := 1.12, secs := SPRING) -> void:
	n.pivot_offset = n.size / 2.0
	n.scale = Vector2.ONE * from
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector2.ONE, secs).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	add(tw, func(): if is_instance_valid(n): n.scale = Vector2.ONE)


## A number ticking from `a` to `b` in a label, text built by `fmt` (one %d).
func count(l: Label, fmt: String, a: float, b: float, secs: float) -> void:
	var rest := l.text
	l.text = fmt % roundi(a)
	var tw := l.create_tween()
	tw.tween_method(func(v: float): if is_instance_valid(l): l.text = fmt % roundi(v), a, b, secs) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	add(tw, func(): if is_instance_valid(l): l.text = rest)
