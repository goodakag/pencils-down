extends GutTest

func test_prompt_copy() -> void:
	var p := MarkingPrompt.build("Unit 3", 4)
	assert_true(p.begins_with('I just finished a practice test called "Unit 3" (4 pages).'))
	assert_string_contains(p, "My pencil work is drawn on the pages and my typed answers are real text.")
	assert_string_contains(p, "4. List the topics I should review, most important first.")

func test_prompt_title_verbatim() -> void:
	assert_string_contains(MarkingPrompt.build('Bob\'s "final"', 1), 'Bob\'s "final"')

func test_single_page_wording() -> void:
	assert_string_contains(MarkingPrompt.build("Quiz", 1), "(1 page)")

func test_format_duration() -> void:
	assert_eq(MarkingPrompt.mmss(0.0), "0:00")
	assert_eq(MarkingPrompt.mmss(754.4), "12:34")
	assert_eq(MarkingPrompt.mmss(3725.0), "1:02:05")

func test_local_date_time_applies_bias() -> void:
	# 2026-10-19 20:40 UTC at UTC-4 (bias -240 minutes) is 16:40 local.
	var unix := int(Time.get_unix_time_from_datetime_string("2026-10-19T20:40:00"))
	assert_eq(MarkingPrompt.local_date_time(unix, -240), "2026-10-19 16:40")
