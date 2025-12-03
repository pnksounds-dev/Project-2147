extends Node
class_name PerformanceMonitor

## Performance monitoring system for tracking game performance
## Monitors FPS, memory usage, and system health

@export var monitoring_enabled: bool = true
@export var update_interval: float = 1.0  # Update every second
@export var log_performance: bool = false
@export var performance_threshold_fps: float = 30.0

var fps_history: Array[float] = []
var memory_history: Array[float] = []  # Changed to float array for precision
var max_history_size: int = 60  # Keep 60 seconds of history

var update_timer: Timer
var current_fps: float = 0.0
var current_memory: float = 0.0  # Changed to float for precision
var performance_warnings: int = 0

signal performance_alert(type: String, message: String, data: Dictionary)

func _ready():
	name = "PerformanceMonitor"
	add_to_group("performance_monitor")
	
	# Set up update timer
	update_timer = Timer.new()
	update_timer.wait_time = update_interval
	update_timer.timeout.connect(_update_performance_stats)
	add_child(update_timer)
	update_timer.start()
	
	print("PerformanceMonitor: Initialized with ", update_interval, "s interval")

func _update_performance_stats():
	"""Update performance statistics"""
	if not monitoring_enabled:
		return
	
	# Get current FPS
	current_fps = Engine.get_frames_per_second()
	fps_history.append(current_fps)
	
	# Get memory usage using Godot 4 API
	# Note: Godot 4 simplified memory API - use get_static_memory_usage() for total static memory
	var memory_bytes = OS.get_static_memory_usage()
	current_memory = float(memory_bytes) / (1024 * 1024)  # Convert to MB with float division
	memory_history.append(current_memory)
	
	# Limit history size
	if fps_history.size() > max_history_size:
		fps_history.pop_front()
	if memory_history.size() > max_history_size:
		memory_history.pop_front()
	
	# Check for performance issues
	_check_performance_issues()
	
	# Log if enabled
	if log_performance:
		_log_performance()

func _check_performance_issues():
	"""Check for performance problems"""
	# Check FPS
	if current_fps < performance_threshold_fps:
		performance_warnings += 1
		performance_alert.emit("fps_warning", "Low FPS detected", {
			"fps": current_fps,
			"threshold": performance_threshold_fps,
			"warnings_count": performance_warnings
		})
		
		if performance_warnings % 5 == 0:  # Every 5th warning
			print("PerformanceMonitor: CRITICAL - Sustained low FPS: ", current_fps)
	
	# Check memory usage
	if current_memory > 500:  # More than 500MB
		performance_alert.emit("memory_warning", "High memory usage detected", {
			"memory_mb": current_memory,
			"history_size": memory_history.size()
		})
		
		if current_memory > 1000:  # More than 1GB
			print("PerformanceMonitor: CRITICAL - Very high memory usage: ", current_memory, "MB")

func _log_performance():
	"""Log performance data"""
	var avg_fps = _calculate_average(fps_history)
	var avg_memory = _calculate_average(memory_history)
	
	print("PerformanceMonitor: FPS=", current_fps, " (avg=", avg_fps, "), Memory=", current_memory, "MB (avg=", avg_memory, "MB)")

func _calculate_average(values: Array) -> float:
	"""Calculate average of array values"""
	if values.is_empty():
		return 0.0
	
	var sum = 0.0
	for value in values:
		sum += value
	
	return sum / values.size()

func get_performance_report() -> Dictionary:
	"""Get comprehensive performance report"""
	return {
		"current_fps": current_fps,
		"average_fps": _calculate_average(fps_history),
		"min_fps": _get_min_value(fps_history),
		"max_fps": _get_max_value(fps_history),
		"current_memory_mb": current_memory,
		"average_memory_mb": _calculate_average(memory_history),
		"min_memory_mb": _get_min_value(memory_history),
		"max_memory_mb": _get_max_value(memory_history),
		"performance_warnings": performance_warnings,
		"monitoring_enabled": monitoring_enabled,
		"history_size": fps_history.size()
	}

func _get_min_value(values: Array) -> float:
	"""Get minimum value from array"""
	if values.is_empty():
		return 0.0
	
	var min_val = values[0]
	for val in values:
		if val < min_val:
			min_val = val
	
	return min_val

func _get_max_value(values: Array) -> float:
	"""Get maximum value from array"""
	if values.is_empty():
		return 0.0
	
	var max_val = values[0]
	for val in values:
		if val > max_val:
			max_val = val
	
	return max_val

func reset_history():
	"""Reset performance history"""
	fps_history.clear()
	memory_history.clear()
	performance_warnings = 0
	print("PerformanceMonitor: History reset")

func set_monitoring(enabled: bool):
	"""Enable or disable monitoring"""
	monitoring_enabled = enabled
	if enabled:
		update_timer.start()
		print("PerformanceMonitor: Monitoring enabled")
	else:
		update_timer.stop()
		print("PerformanceMonitor: Monitoring disabled")
