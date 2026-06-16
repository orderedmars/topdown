extends CanvasLayer

signal choice_selected(choice_id: String)

@onready var panel: Panel = $Panel
@onready var name_label: Label = $Panel/NameLabel
@onready var message_label: Label = $Panel/MessageLabel
@onready var choice_container: VBoxContainer = $Panel/ChoiceContainer

func _ready():
	hide_dialogue()

func show_dialogue(npc_name: String, message: String, choices: Array):
	name_label.text = npc_name
	message_label.text = message
	
	# Clear old choices
	for child in choice_container.get_children():
		child.queue_free()
	
	# Create new choice buttons
	for choice in choices:
		var btn = Button.new()
		btn.text = choice["text"]
		btn.pressed.connect(func(): _on_choice_pressed(choice["id"]))
		choice_container.add_child(btn)
	
	panel.show()
	# Disable player movement here if needed

func hide_dialogue():
	panel.hide()

func _on_choice_pressed(choice_id: String):
	choice_selected.emit(choice_id)
	hide_dialogue()
