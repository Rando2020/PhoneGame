class_name RulesScreen
extends Screen


func build() -> void:
	var body: MarginContainer = UIKit.screen_body(18)
	add_child(body)

	var col: VBoxContainer = UIKit.vbox(10)
	body.add_child(col)

	col.add_child(UIKit.title("HOW TO PLAY", 30))
	col.add_child(UIKit.label(
		"Build Rummy patterns. Spend Focus. Read the enemy intent.",
		14, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)

	var guide: VBoxContainer = UIKit.vbox(10)
	guide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(guide)

	guide.add_child(_section(
		"YOUR TURN",
		"You start each turn with 2 Focus. Playing a meld costs 1 Focus. Cycling one selected card costs 1 Focus and replaces it from the deck. Use End Turn when you are done. Your hand refills toward its normal size next turn."))

	guide.add_child(_section(
		"MELDS",
		"PAIR  →  BRACE\nGain Block.\n\n2-CARD SAME-SUIT RUN  →  PREP\nDraw extra cards and gain +1 Focus.\n\n3+ SAME-SUIT RUN  →  STRIKE\nDeal damage. Longer runs hit harder.\n\n3+ SAME-RANK SET  →  RALLY\nDeal damage and apply Burn.\n\n4 OF ONE RANK, ALL SUITS  →  GRAND MELD\nHeavy damage, Hex, and Block."))

	guide.add_child(_section(
		"STATUS EFFECTS",
		"BLOCK absorbs incoming damage, then half of remaining Block fades at the end of the turn.\n\nBURN deals its current value as damage, then drops by 1.\n\nHEX reduces outgoing attack damage and drops by 1 each turn.\n\nTHORNS damages an attacker when their hit gets through Block."))

	guide.add_child(_section(
		"READ THE TABLE",
		"The enemy shows its next intent before you commit your turn. BRACE when a large hit is coming, PREP when you need more options, and hold strong partial patterns when the payoff is worth the risk. The Hint button will auto-select a legal meld when one is available."))

	guide.add_child(_section(
		"THE CORE CHOICE",
		"A pair can save you now as BRACE, but keeping it may let you build a stronger set later. Meldlings is about deciding when to cash in a pattern and when to gamble on improving it."))

	var back: Button = UIKit.button("BACK", 18, 52)
	back.pressed.connect(func() -> void:
		audio().sfx("ui_click")
		game.goto("title"))
	col.add_child(back)


func _section(title_text: String, body_text: String) -> PanelContainer:
	var panel: PanelContainer = UIKit.panel()
	var col: VBoxContainer = UIKit.vbox(6)
	panel.add_child(col)
	col.add_child(UIKit.label(title_text, 17, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(UIKit.wrap_label(body_text, 300, 14, UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT))
	return panel
