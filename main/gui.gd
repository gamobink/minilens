
extends CanvasLayer

const GOAL_TYPES = ["box", "flower", "artefact"]

var allow_next_level = false
var popup_running = false

onready var timer = get_node("timer")
onready var popup = get_node("popup")
onready var lookaround = get_node("lookaround")
onready var level_holder = get_node("../level_holder")
onready var player = get_node("../player_holder/player")

func _ready():
	ScreenManager.set_minimum_size(Vector2(0, 0))
	
	var nodes_left = get_node("popup/popup_node/body/container").get_children()
	
	# Removes the focus from the buttons
	for button in get_node("top_left_buttons").get_children():
		if button extends Control:
			button.set_focus_mode(Control.FOCUS_NONE)
			
			if button extends BaseButton:
				nodes_left.push_back(button)
	
	# Removes the focus from the buttons
	while nodes_left.size() > 0:
		var button = nodes_left[nodes_left.size() - 1]
		nodes_left.pop_back()
		if button extends BaseButton:
			button.connect("pressed", self, "popup_button_pressed", [button.get_name()])
		else:
			for i in button.get_children():
				nodes_left.push_back(i)
	
	# Show some of the touch buttons depending on settings
	var input_mode = SettingsManager.read_settings().input_mode
	get_node("touch_controls").set_hidden(!OS.has_touchscreen_ui_hint())
	get_node("touch_controls/areas").set_hidden(input_mode != SettingsManager.INPUT_AREAS)
	get_node("touch_controls/areas").set_ignore_mouse(input_mode != SettingsManager.INPUT_AREAS)
	get_node("touch_controls/buttons").set_hidden(input_mode != SettingsManager.INPUT_BUTTONS)
	get_node("touch_controls/buttons").set_ignore_mouse(input_mode != SettingsManager.INPUT_BUTTONS)
	
	
	# Subscribe to various notifications
	level_holder.connect("counters_changed", self, "update_counters")
	set_process_input(true)

func _input(event):
	if event.is_action_pressed("retry"):
		popup_button_pressed("retry")
	if event.is_action_pressed("next_level"):
		popup_button_pressed("next")
	if event.is_action_pressed("exit"):
		popup_button_pressed("menu")

func update_counters():
	get_node("counters/resources/bomb/label").set_text(str(" x ", player.bombs))
	get_node("counters/resources/turns/label").set_text(str(level_holder.turns))
	
	for goal_type in GOAL_TYPES:
		if level_holder.goals_total.has(goal_type) and level_holder.goals_total[goal_type] > 0:
			get_node("counters/resources").get_node(goal_type).show()
			var label = get_node("counters/resources").get_node(goal_type).get_node("label")
			label.set_text(str(level_holder.goals_taken[goal_type], " / ", level_holder.goals_total[goal_type]))
		else:
			get_node("counters/resources").get_node(goal_type).hide()
	
	if not level_holder.goals_total.has("box"):
		var node = get_node("counters/resources/flower")
		node.set_pos(Vector2(0, 90))

func prompt_retry_level(wait = 0): # Called when the robot dies
	if not popup_running or allow_next_level:
		allow_next_level = false
		show_popup("You died", "Your robot was destroyed!\n Do you want to try again?", wait)

func prompt_impossible_level(wait = 0): # Called when the level is impossible
	if not popup_running or allow_next_level:
		allow_next_level = false
		show_popup("Impossible", "It seems that it is impossible to pass this level!\nDo you want to try again?", wait)

func prompt_finsh_level(turns = 1, has_more_levels = true, wait = 0): # Called when the level is passed
	if not popup_running:
		allow_next_level = has_more_levels
		
		var body_text = str("Level passed in ", turns, " turns.")
		if !has_more_levels:
			body_text = str(body_text, "\nYou completed all the levels of this pack. Select another pack to play in the level selection menu.")
		
		show_popup("Good job!", body_text, wait)

func show_popup(title, text, wait): # Show a popup with title and text, after some time
	popup_running = true
	if timer.is_connected("timeout", self, "_show_popup"):
		timer.disconnect("timeout", self, "_show_popup")
	if wait > 0:
		timer.set_wait_time(wait)
		timer.connect("timeout", self, "_show_popup", [title, text], CONNECT_ONESHOT)
		timer.start()
	else:
		_show_popup(title, text)

func _show_popup(title, text): # Show a popup with title and text
	set_disabled(true)
	if lookaround.enabled:
		get_node("top_left_buttons/look").set_pressed(false)
		popup_button_pressed("look")
		yield(lookaround.animation_player, "finished")
	get_tree().set_pause(true)
	
	popup.get_node("popup_node/header/title").set_text(title)
	popup.get_node("popup_node/body/container/text").set_text(text)
	popup.get_node("popup_node/body/container/level_buttons/next").set_hidden(!allow_next_level)
	
	popup.get_node("AnimationPlayer").play("show_popup")
	popup.show()

func popup_button_pressed(name): # Actions for different popup buttons
	if name == "look":
		var toggled = get_node("top_left_buttons/look").is_pressed()
		lookaround.set_enabled(toggled)
	elif name == "speed":
		var speed = config.speed_ratio*2
		if speed > 4:
			speed = 1
		config.speed_ratio = speed
		get_node("top_left_buttons/speed/text").set_text(str("x", str(config.speed_ratio)))
	if name == "retry":
		check_hide_popup()
		level_holder.retry_level()
	elif name == "next":
		if allow_next_level:
			check_hide_popup()
			allow_next_level = false
			level_holder.next_level()
		else:
			return
	elif name == "menu":
		get_tree().set_pause(false)
		ScenesManager.load_scene("res://menu/menu.tscn")

func check_hide_popup():
	if popup_running:
		get_tree().set_pause(false)
		popup.get_node("AnimationPlayer").play("hide_popup")
		popup.get_node("AnimationPlayer").connect("finished", self, "hide_popup", [], CONNECT_ONESHOT)

func hide_popup(): # Hide the popup
	popup_running = false
	popup.hide()
	set_disabled(false)

func set_disabled(disable):
	for node in get_node("top_left_buttons").get_children():
		if node extends Button:
			node.set_disabled(disable)