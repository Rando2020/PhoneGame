class_name HandView
extends Control

## Lays out a hand of cards and handles selection.
##
## Meldlings: selection is a keep. Up to `max_select` cards may be chosen, and
## exactly `max_select` is the valid state (set it from CribRound.keep_count()).
## The Rummy MeldRules coupling from godot-legacy was removed here.
##
## Views are kept alive across adds, removes and sorts, so cards *slide* into
## their new positions rather than snapping. Selection is tracked by CardView
## reference (not index) so sorting can't scramble it.

signal selection_changed(cards: Array, verdict: Dictionary)
signal card_activated(index: int)      ## double-tap
signal layout_settled()
signal deal_finished()              ## emitted when deal() has laid every card

@export var max_overlap_gap: int = 12  ## min px between card left edges when crowded
@export var lift_amount: float = 24.0
@export var show_hints: bool = true
@export var slide_time: float = 0.22
@export var fan_tilt_deg: float = 0.0  ## >0 gives the hand a slight arc
@export var max_select: int = 4        ## the keep size; exactly this many is valid

var _cards: Array = []                 ## Array[Dictionary] {rank, suit}
var _views: Array[CardView] = []
var _selected: Array[CardView] = []
var _last_press_view: CardView = null
var _last_press_time: int = 0
var _dealing: bool = false


func _ready() -> void:
	clip_contents = false
	mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(func(): _layout(false))


# ------------------------------------------------------------------ queries
func get_cards() -> Array:
	return _cards.duplicate(true)


func get_selected_cards() -> Array:
	var out: Array = []
	for v in _selected:
		var i := _views.find(v)
		if i >= 0:
			out.append(_cards[i])
	return out


func get_selected_indices() -> Array[int]:
	var out: Array[int] = []
	for v in _selected:
		var i := _views.find(v)
		if i >= 0:
			out.append(i)
	out.sort()
	return out


func index_of_view(view: CardView) -> int:
	return _views.find(view)


func card_count() -> int:
	return _cards.size()


## Screen position of a card slot -- what CardAnimator needs as a flight target.
func slot_global_position(index: int) -> Vector2:
	var geo := _slot_geometry(_cards.size())
	var card_h: float = CardArt.BASE_H * CardView.PIXEL_SCALE
	return global_position + Vector2(geo.start_x + geo.spacing * index, size.y - card_h)


## Where a card would land if it were appended right now.
func next_slot_global_position() -> Vector2:
	var geo := _slot_geometry(_cards.size() + 1)
	var card_h: float = CardArt.BASE_H * CardView.PIXEL_SCALE
	return global_position + Vector2(geo.start_x + geo.spacing * _cards.size(), size.y - card_h)


# ------------------------------------------------------------------ mutation
func set_cards(cards: Array, animate: bool = true) -> void:
	for v in _views:
		if is_instance_valid(v):
			v.queue_free()
	_views.clear()
	_selected.clear()
	_cards = cards.duplicate(true)
	for c in _cards:
		_views.append(_make_view(c))
	_layout(false)
	if animate:
		for v in _views:
			v.appear()
	_apply_states()


## Append one card without disturbing the others. `hidden` keeps it invisible so
## a CardAnimator flight can land on it -- call reveal_last() when it arrives.
func append_card(card: Dictionary, hidden: bool = false) -> int:
	_cards.append(card)
	var v := _make_view(card)
	_views.append(v)
	if hidden:
		v.modulate.a = 0.0
	_layout(true)
	if not hidden:
		v.appear()
	_apply_states()
	return _cards.size() - 1


func reveal_at(index: int, pop: bool = true) -> void:
	if index < 0 or index >= _views.size():
		return
	var v := _views[index]
	v.modulate.a = 1.0
	if pop:
		v.pop(0.18)


func reveal_last(pop: bool = true) -> void:
	reveal_at(_views.size() - 1, pop)


func remove_at(index: int, animate: bool = true) -> Dictionary:
	if index < 0 or index >= _cards.size():
		return {}
	var c: Dictionary = _cards[index]
	var v := _views[index]
	_cards.remove_at(index)
	_views.remove_at(index)
	_selected.erase(v)
	if animate:
		v.vanish()
	else:
		v.queue_free()
	_layout(true)
	_apply_states()
	_emit_selection()
	return c


func remove_selected(animate: bool = true) -> Array:
	var idx := get_selected_indices()
	idx.reverse()
	var taken: Array = []
	for i in idx:
		taken.push_front(_cards[i])
		var v := _views[i]
		_cards.remove_at(i)
		_views.remove_at(i)
		if animate:
			v.vanish()
		else:
			v.queue_free()
	_selected.clear()
	_layout(true)
	_apply_states()
	_emit_selection()
	return taken


func clear_selection() -> void:
	_selected.clear()
	_apply_states()
	_emit_selection()


# ------------------------------------------------------------------ sorting
func sort_by_rank() -> void:
	_resort(func(a, b):
		if int(a[0].rank) == int(b[0].rank):
			return CardArt.suit_index(a[0].suit) < CardArt.suit_index(b[0].suit)
		return int(a[0].rank) < int(b[0].rank))


func sort_by_suit() -> void:
	_resort(func(a, b):
		var sa := CardArt.suit_index(a[0].suit)
		var sb := CardArt.suit_index(b[0].suit)
		if sa == sb:
			return int(a[0].rank) < int(b[0].rank)
		return sa < sb)


func _resort(cmp: Callable) -> void:
	## Sort card+view pairs together so views keep their identity and slide.
	var pairs: Array = []
	for i in _cards.size():
		pairs.append([_cards[i], _views[i]])
	pairs.sort_custom(cmp)
	_cards.clear()
	_views.clear()
	for p in pairs:
		_cards.append(p[0])
		_views.append(p[1])
	_layout(true)
	_apply_states()
	_emit_selection()


# ------------------------------------------------------------------ layout
func _make_view(card: Dictionary) -> CardView:
	var v := CardView.new()
	add_child(v)
	v.setup_card(card)
	v.pressed.connect(_on_card_pressed)
	return v


func _slot_geometry(n: int) -> Dictionary:
	var card_w: float = CardArt.BASE_W * CardView.PIXEL_SCALE
	var avail: float = maxf(card_w, size.x)
	var spacing: float = card_w + 8.0
	if n > 1 and card_w + spacing * (n - 1) > avail:
		spacing = maxf(float(max_overlap_gap), (avail - card_w) / float(n - 1))
	var total: float = card_w + spacing * maxi(0, n - 1)
	return {"spacing": spacing, "start_x": (avail - total) * 0.5}


func _layout(animate: bool = true) -> void:
	if _views.is_empty():
		return
	var geo := _slot_geometry(_views.size())
	var card_h: float = CardArt.BASE_H * CardView.PIXEL_SCALE
	var y: float = size.y - card_h
	var mid: float = (_views.size() - 1) * 0.5

	for i in _views.size():
		var v := _views[i]
		if not is_instance_valid(v):
			continue
		v.z_index = i
		var pos := Vector2(geo.start_x + geo.spacing * i, y)
		if fan_tilt_deg > 0.0 and _views.size() > 1:
			var t := (i - mid) / maxf(1.0, mid)
			pos.y += absf(t) * fan_tilt_deg * 1.6
			v.base_rotation = deg_to_rad(t * fan_tilt_deg)
			if not v in _selected:
				v.rotation = v.base_rotation
		v.set_base_position(pos, animate and not _dealing)
		if v in _selected:
			v.lift(lift_amount, animate)

	if animate:
		var tw := create_tween()
		tw.tween_interval(slide_time)
		tw.tween_callback(func(): layout_settled.emit())


# ------------------------------------------------------------------ input
func _on_card_pressed(view: CardView) -> void:
	var index := _views.find(view)
	if index < 0:
		return

	var now := Time.get_ticks_msec()
	if view == _last_press_view and now - _last_press_time < 320:
		_last_press_view = null
		card_activated.emit(index)
		return
	_last_press_view = view
	_last_press_time = now

	if view in _selected:
		_selected.erase(view)
	else:
		if _selected.size() >= max_select:
			view.flash_reject()
			return
		_selected.append(view)

	_apply_states()
	_emit_selection()


## The keep's verdict: {valid, count, need}. Replaces MeldRules.classify.
func verdict() -> Dictionary:
	return {"valid": _selected.size() == max_select, "count": _selected.size(), "need": max_select}


func _apply_states() -> void:
	var v_ := verdict()
	var full: bool = _selected.size() >= max_select

	for i in _views.size():
		var v := _views[i]
		if not is_instance_valid(v):
			continue
		if v in _selected:
			v.set_state(CardView.State.VALID if v_.valid else CardView.State.SELECTED)
			v.lift(lift_amount)
			v.set_hover(true)
			if v_.valid:
				v.pop(0.10, 0.18)
		else:
			v.set_hover(false)
			v.settle()
			# Once the keep is full, the rest are the throw: dim them.
			v.set_state(CardView.State.DIM if show_hints and full else CardView.State.NORMAL)


func _emit_selection() -> void:
	selection_changed.emit(get_selected_cards(), verdict())


# ------------------------------------------------------------------ assist
## Select exactly these positions (e.g. a suggested keep). Replaces autoselect_best_meld.
func select_indices(idx: Array) -> void:
	_selected.clear()
	for i in idx:
		if i >= 0 and i < _views.size() and _selected.size() < max_select:
			_selected.append(_views[i])
	_apply_states()
	_emit_selection()


## Deal cards in one at a time with a stagger. Await it before enabling input.
func deal(cards: Array, stagger: float = 0.06) -> void:
	# A node-owned tween sequence, not awaited timers: a coroutine suspended on
	# timers leaked one object per hand freed mid-deal (measured). Listen for
	# deal_finished instead of awaiting.
	_dealing = true
	set_cards([], false)
	if _deal_seq and _deal_seq.is_valid():
		_deal_seq.kill()
	_deal_seq = create_tween()
	for c in cards:
		_deal_seq.tween_callback(func():
			append_card(c, true)
			reveal_last())
		_deal_seq.tween_interval(stagger)
	_deal_seq.tween_callback(func():
		_dealing = false
		_layout(true)
		deal_finished.emit())


var _deal_seq: Tween
