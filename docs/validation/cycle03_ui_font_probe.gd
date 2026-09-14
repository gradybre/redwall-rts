extends SceneTree
var checks: int = 0
var failures: int = 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL ", label)
func _initialize() -> void:
	var font: Font = load("res://ui/fonts/NotoSans-SemiBold.ttf")
	var regular: Font = load("res://ui/fonts/NotoSans-Regular.ttf")
	check(font != null and regular != null, "vendored fonts available")
	if font == null or regular == null:
		quit(1)
		return
	check(regular.get_height(14) + font.get_height(18) + 8 <= 56, "two resource lines fit")
	check(maxf(font.get_height(16),24) + 24 <= 48, "full notice fits 48")
	check(maxf(font.get_height(16),24) + 16 <= 44, "summary fits 44")
	for width: float in [328.0/3.0-8.0,136.0,96.0]:
		for value: String in ["5.48 days","256 / 256","1,000 U","0.00 days"]:
			check(font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x <= width, "value "+value)
		for value: String in ["See ledger","Unavailable"]:
			check(regular.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x <= width, "disclosure "+value)
	check(regular.get_string_size("Ready food",HORIZONTAL_ALIGNMENT_LEFT,-1,14).x+20 <=328.0/3.0-8.0, "standard caption and icon")
	check(regular.get_string_size("Residents",HORIZONTAL_ALIGNMENT_LEFT,-1,14).x+20<=96, "narrow residents caption and icon")
	check(font.get_string_size("999.99 days",HORIZONTAL_ALIGNMENT_LEFT,-1,18).x>328.0/3.0-8.0, "long standard food value requires disclosure")
	check(font.get_string_size("9,223,372,036,854,775.807 U",HORIZONTAL_ALIGNMENT_LEFT,-1,18).x>136, "large exact quantity requires disclosure")
	print("CYCLE3 FONT PROBE: ", checks," checks, ",failures," failures")
	print("caption14=",regular.get_height(14)," number18=",font.get_height(18)," notice16=",font.get_height(16))
	quit(0 if failures == 0 else 1)
