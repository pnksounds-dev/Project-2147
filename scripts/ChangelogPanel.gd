extends Control

class_name ChangelogPanel

## ChangelogPanel - Displays the user-friendly changelog in the main menu

@onready var scroll_container: ScrollContainer = $VBoxContainer/ScrollContainer if has_node("VBoxContainer/ScrollContainer") else null
@onready var rich_text_label: RichTextLabel = $VBoxContainer/ScrollContainer/ChangelogLabel if has_node("VBoxContainer/ScrollContainer/ChangelogLabel") else null

# Audio manager reference
var audio_manager

func _ready():
	add_to_group("changelog_panel")
	
	# Get audio manager
	audio_manager = get_node_or_null("/root/AudioManager")
	
	# Load changelog content
	_load_changelog_content()

func _load_changelog_content():
	"""Load and display the changelog content"""
	var changelog_file = FileAccess.open("res://ChangeLog/CHANGELOG-latest.md", FileAccess.READ)
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
	
	# Convert headers to different sizes with colors
	formatted = formatted.replace("# Game Development Changelog", "[color=#2196F3][font_size=32][b]📝 Game Development Changelog[/b][/font_size][/color]")
	formatted = formatted.replace("## **", "[color=#FF9800][font_size=24][b]▶ ")
	formatted = formatted.replace("### **V", "[color=#4CAF50][font_size=20]▶ V")
	formatted = formatted.replace("### **", "[color=#4CAF50][font_size=20]• ")
	formatted = formatted.replace("#### ", "[color=#9C27B0][font_size=18]• ")
	
	# Convert bold text **text** to [b]text[/b]
	formatted = regex_replace(formatted, r"\*\*(.*?)\*\*", "[b]$1[/b]")
	
	# Convert bullet points
	var lines = formatted.split("\n")
	var result_lines = []
	
	for line in lines:
		if line.begins_with("- "):
			# Convert bullet points with indentation
			result_lines.append("    • " + line.substr(2))
		elif line.begins_with("#### Files Added/Modified"):
			result_lines.append("\n[color=#9C27B0][font_size=18][b]" + line + "[/b][/font_size][/color]")
		else:
			result_lines.append(line)
	
	return "\n".join(result_lines)

func regex_replace(text: String, pattern: String, replacement: String) -> String:
	"""Simple regex replacement function"""
	var regex = RegEx.new()
	regex.compile(pattern)
	return regex.sub(text, replacement, true)
