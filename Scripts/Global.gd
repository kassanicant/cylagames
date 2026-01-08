extends Node

var current_level = 1

# [Number of Boxes, Number of Dummies, Time in Seconds]
var level_data = {
	1: {"boxes": 3, "dummies": 0, "time": 60},
	2: {"boxes": 4, "dummies": 0, "time": 60},
	3: {"boxes": 6, "dummies": 0, "time": 90},
	4: {"boxes": 8, "dummies": 2, "time": 100},
	5: {"boxes": 10, "dummies": 3, "time": 120},
	6: {"boxes": 12, "dummies": 4, "time": 150}
}
