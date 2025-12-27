extends Label

# SETTINGS
@export var show_system_time: bool = true # TRUE = Real Clock, FALSE = Timer starting at 0
@export var show_date: bool = true
@export var blink_rec_dot: bool = true

# Internal variables
var time_elapsed: float = 0.0

func _process(delta: float) -> void:
	var time_str = ""
	
	if show_system_time:
		# Option A: Real World Clock
		var time = Time.get_time_dict_from_system()
		var hour = time.hour
		var am_pm = "AM"
		
		# Convert 24h to 12h format
		if hour >= 12:
			am_pm = "PM"
			if hour > 12: hour -= 12
		if hour == 0: hour = 12
		
		time_str = "%02d:%02d:%02d %s" % [hour, time.minute, time.second, am_pm]
		
		if show_date:
			var date = Time.get_date_dict_from_system()
			var date_str = "%s. %02d %d" % [get_month_name(date.month), date.day, date.year]
			# Removed "PLAY" here
			text = "%s\n%s" % [time_str, date_str]
		else:
			# Removed "PLAY" here
			text = "%s" % [time_str]
			
	else:
		# Option B: "REC" Timer
		time_elapsed += delta
		var total_sec = int(time_elapsed)
		var seconds = total_sec % 60
		var minutes = (total_sec / 60) % 60
		var hours = (total_sec / 3600)
		
		# Blinking Red Dot logic
		var dot = "●" if (int(time_elapsed * 2) % 2 == 0) and blink_rec_dot else " "
		
		text = "%s REC   %02d:%02d:%02d" % [dot, hours, minutes, seconds]

# Helper to get Month Name
func get_month_name(month: int) -> String:
	var months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
	if month > 0 and month <= 12:
		return months[month - 1]
	return "ERR"
