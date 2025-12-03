extends Control

class_name ChangelogPanel

## ChangelogPanel - Displays the user-friendly changelog in the main menu

@onready var scroll_container: ScrollContainer = $VBoxContainer/ScrollContainer if has_node("VBoxContainer/ScrollContainer") else null
@onready var rich_text_label: RichTextLabel = $VBoxContainer/ScrollContainer/RichTextLabel if has_node("VBoxContainer/ScrollContainer/RichTextLabel") else null
@onready var back_button: Button = $VBoxContainer/BackButton if has_node("VBoxContainer/BackButton") else null

# Audio manager reference
var audio_manager

func _ready():
	add_to_group("changelog_panel")
	
	# Get audio manager
	audio_manager = get_node_or_null("/root/AudioManager")
	
	# Load changelog content
	_load_changelog_content()
	
	# Connect back button
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

func _load_changelog_content():
	"""Load and display the changelog content"""
	var changelog_file = FileAccess.open("res://ChangeLog/CHANGELOG.md", FileAccess.READ)
	if changelog_file:
		var content = changelog_file.get_as_text()
		changelog_file.close()
		
		# Convert markdown to basic RichTextLabel format
		var formatted_content = _format_markdown_for_richtext(content)
		
		if rich_text_label:
			rich_text_label.text = formatted_content
	else:
		print("ChangelogPanel: Could not load changelog file")
		if rich_text_label:
			rich_text_label.text = "[color=red]Changelog file not found![/color]"

func _format_markdown_for_richtext(markdown: String) -> String:
	"""Convert basic markdown to RichTextLabel format"""
	var formatted = markdown
	
	# Convert headers to different sizes
	formatted = formatted.replace("# ", "[font_size=32][b]")
	formatted = formatted.replace("## ", "[font_size=24][b]")
	formatted = formatted.replace("### ", "[font_size=20][b]")
	formatted = formatted.replace("#### ", "[font_size=18][b]")
	formatted = formatted.replace("##### ", "[font_size=16][b]")
	formatted = formatted.replace("###### ", "[font_size=14][b]")
	
	# Convert bold text **text** to [b]text[/b]
	formatted = regex_replace(formatted, r"\*\*(.*?)\*\*", "[b]$1[/b]")
	
	# Convert italic text *text* to [i]text[/i]
	formatted = regex_replace(formatted, r"\*(.*?)\*", "[i]$1[/i]")
	
	# Convert emojis to keep them (they're already fine)
	# No conversion needed for emojis
	
	# Convert bullet points
	var lines = formatted.split("\n")
	var result_lines = []
	
	for line in lines:
		if line.begins_with("- "):
			# Convert bullet points
			result_lines.append("    • " + line.substr(2))
		elif line.begins_with("### **"):
			# Special handling for version headers
			result_lines.append("\n" + line)
		else:
			result_lines.append(line)
	
	return "\n".join(result_lines)

func regex_replace(text: String, pattern: String, replacement: String) -> String:
	"""Simple regex replacement function"""
	var regex = RegEx.new()
	regex.compile(pattern)
	return regex.sub(text, replacement, true)

func _on_back_pressed():
	"""Handle back button press"""
	if audio_manager:
		audio_manager.play_button_click()
	
	# Hide changelog panel
	visible = false
	
	# Return to home mode
	var main_menu = get_parent()
	if main_menu and main_menu.has_method("_switch_mode"):
		# Find the start button and switch to home mode
		var start_btn = main_menu.get_node_or_null("CanvasLayer/TopBarContainer/TopBarCenter/TopButtons/StartButton")
		if start_btn:
			main_menu._switch_mode(main_menu.Mode.HOME, start_btn)
