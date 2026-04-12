class_name ChunkGenProfiler
extends Node

# For benchmarking chunk gen times.
var is_benchmarking: bool = true
var stat_generation_start_time: int = 0
var total_visual_time: int = 0
var visual_commit_count: int = 0
var stop_timing_chunk_generation: bool = false
var stat_mutex: Mutex = Mutex.new()
var stat_generate_mesh_total: int = 0
var stat_generate_mesh_count: int = 0
var stat_add_face_total: int = 0
var stat_add_face_count: int = 0
var stat_chunks_expected: int = 0
var stat_chunks_reported: int = 0
var stat_generation_complete: bool = false
var stat_generate_data_total: int = 0
var stat_generate_data_count: int = 0
var stat_perface_mesh_total: int = 0
var stat_transparent_mesh_total: int = 0

func record_visual_commit(time_ms: int) -> void:
	total_visual_time += time_ms
	visual_commit_count += 1

func begin(chunks_expected: int) -> void:
	stat_chunks_expected = chunks_expected
	stat_generation_start_time = Time.get_ticks_msec()

func report_stats(generate_mesh_us: int, add_face_us: int, add_face_calls: int, generate_data_us: int, greedy_mesh_us: int, transparent_mesh_us: int) -> void:
	if not is_benchmarking:
		return
	stat_mutex.lock()
	stat_generate_mesh_total += generate_mesh_us
	stat_generate_mesh_count += 1
	stat_add_face_total += add_face_us
	stat_add_face_count += add_face_calls
	stat_generate_data_total += generate_data_us
	stat_generate_data_count += 1
	stat_perface_mesh_total += greedy_mesh_us
	stat_transparent_mesh_total += transparent_mesh_us
	stat_chunks_reported += 1
	var all_done: bool = stat_chunks_reported >= stat_chunks_expected and not stat_generation_complete
	if all_done:
		stat_generation_complete = true
	stat_mutex.unlock()

	if all_done:
		print_generation_stats.call_deferred()

func print_generation_stats() -> void:
	print("=== Generation Complete: %d chunks ===" % stat_chunks_reported)
	print("  total time:        %d ms" % (Time.get_ticks_msec() - stat_generation_start_time))
	if stat_generate_data_count > 0:
		print("  generate_data:     avg %.2f us over %d chunks" % [
			float(stat_generate_data_total) / stat_generate_data_count,
			stat_generate_data_count])
	if stat_generate_mesh_count > 0:
		print("  generate_mesh:     avg %.2f us over %d chunks" % [
			float(stat_generate_mesh_total) / stat_generate_mesh_count,
			stat_generate_mesh_count])
	if stat_generate_mesh_count > 0:
		print("  per-face_mesh:       avg %.2f us over %d chunks" % [
			float(stat_perface_mesh_total) / stat_generate_mesh_count,
			stat_generate_mesh_count])
	if stat_generate_mesh_count > 0:
		print("  transparent_mesh:  avg %.2f us over %d chunks" % [
			float(stat_transparent_mesh_total) / stat_generate_mesh_count,
			stat_generate_mesh_count])
	if stat_add_face_count > 0:
		print("  add_face:          called %d times total, avg %.4f us each" % [
			stat_add_face_count,
			float(stat_add_face_total) / stat_add_face_count])
	if visual_commit_count > 0:
		print("  commit_visuals:    avg %.2f ms over %d chunks" % [
			float(total_visual_time) / visual_commit_count,
			visual_commit_count])
