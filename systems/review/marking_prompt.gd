class_name MarkingPrompt
extends RefCounted
## The prompt the player pastes into an AI, together with the exported PDF and their answer key.


static func build(test_title: String, page_count: int) -> String:
	return ("I just finished a practice test called \"%s\" (%d %s). I've attached my completed test as a PDF. My pencil work is drawn on the pages and my typed answers are real text. I've also attached the answer key.\n\n"
		+ "Please mark it question by question:\n"
		+ "1. For each question, say whether my answer is correct, partly correct, or wrong.\n"
		+ "2. For anything not fully correct, explain the mistake briefly and show the right method.\n"
		+ "3. Give my total score and percentage.\n"
		+ "4. List the topics I should review, most important first.") % [test_title, page_count, "page" if page_count == 1 else "pages"]


## 754 → "12:34"; 3725 → "1:02:05".
static func mmss(seconds: float) -> String:
	var s := int(round(seconds))
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
	return "%d:%02d" % [s / 60, s % 60]
