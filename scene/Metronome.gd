class_name Metronome
extends Control

@onready var audioPlayer := $AudioPlayer;
@onready var buttonSound := $HBox/Buttons/ButtonSound;
@onready var button_low := $HBox/VBox/Bpm/ButtonLow;
@onready var button_high := $HBox/VBox/Bpm/ButtonHigh;
@onready var lineEdit_bpm := $HBox/VBox/Bpm/LineEditBpm;
@onready var slider_bpm := $HBox/VBox/SliderBpm;
@onready var spinBox_beat_count := $HBox/VBox/BeatCount;
@onready var beat_visual := $HBox/VBox/BeatVisual;
@onready var tester := $HBox/Buttons/Tester;

const BEAT_VISUAL_COLOR = Color(1,1,0.65);
const BEAT_VISUAL_STYLEBOX = preload("res://scene/BeatVisualPad.stylebox");
var beat_visual_stylebox_array := [];

var enabled := false;

var bpm :int = 80;
var last_beat :float = 0.0;
var beat_count :int = 4:
	set(value):
		if beat_count != value:
			beat_count = value;
			build_beat_visual();
var beat_index :int = 0;

var tester_start_tap :float = 0;
var tester_last_tap :float = 0;
var tester_beats :int = 0;

signal beat();


func _ready() -> void:
	
	lineEdit_bpm.text = str(bpm);
	slider_bpm.value = bpm;
	
	lineEdit_bpm.text_changed.connect(lineEdit_bpm_text_changed);
	slider_bpm.value_changed.connect(set_bpm);
	spinBox_beat_count.get_line_edit().focus_mode = Control.FOCUS_NONE;
	spinBox_beat_count.value_changed.connect(func(value: float): 
		beat_count = value; reset_beat();
		spinBox_beat_count.get_line_edit().release_focus();
	);
	button_high.pressed.connect(func(): lineEdit_bpm_text_changed(str(lineEdit_bpm.text.to_int()+1)));
	button_low.pressed.connect(func(): lineEdit_bpm_text_changed(str(lineEdit_bpm.text.to_int()-1)));
	buttonSound.pressed.connect(func(): reset_beat());
	tester.pressed.connect(tap_beat_tester);
	
	build_beat_visual();
	reset_beat();


func _process(delta: float) -> void:
	
	if !enabled: return;
	
	var beat_time = 60.0/bpm;
	var now_time = get_time();
	var interval = now_time - last_beat;
	if interval > beat_time:
		
		last_beat = now_time - (interval - beat_time);
		
		beat_index = beat_index + 1 if beat_index < beat_count else 1;
		
		if buttonSound.button_pressed:
			audioPlayer.pitch_scale = 1.1 if beat_index == 1 else 1;
			audioPlayer.volume_db = 0 if beat_index == 1 else -5;
			audioPlayer.play();
		
		beat.emit();
		
		if beat_visual_stylebox_array.size() == beat_count:
			var tween = create_tween();
			tween.parallel().tween_property(beat_visual_stylebox_array[beat_index-1], "bg_color",
			Color.TRANSPARENT, beat_time).from(BEAT_VISUAL_COLOR
				).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC);


## 更新回第一拍
func reset_beat():
	beat_index = 0;
	last_beat = get_time() - 60.0/bpm;

## 设定bpm并更新节点
func set_bpm(bpm: int):
	self.bpm = bpm;
	lineEdit_bpm.text = str(bpm);
	slider_bpm.value = bpm;

## LineEditBpm的输入控制
func lineEdit_bpm_text_changed(new_text: String):
	if new_text.begins_with("0"):
		lineEdit_bpm.text = new_text.substr(1);
		new_text = new_text.substr(1);
	elif new_text == "":
		lineEdit_bpm.text = "0";
		lineEdit_bpm.caret_column = 1;
		buttonSound.button_pressed = false;
		return;
	if new_text.is_valid_int():
		set_bpm(new_text.to_int());
		lineEdit_bpm.text = new_text;
	else:
		lineEdit_bpm.text = str(bpm);
	lineEdit_bpm.caret_column = lineEdit_bpm.text.length();

## 构建可视化节拍器
func build_beat_visual():
	
	beat_visual_stylebox_array.clear();
	for child in beat_visual.get_children():
		beat_visual.remove_child(child);
		child.queue_free();
	
	var stylebox_array := [];
	
	for i in range(0,beat_count):
		var panel := Panel.new();
		panel.custom_minimum_size = Vector2(0,40);
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL;
		var stylebox = BEAT_VISUAL_STYLEBOX.duplicate();
		stylebox.bg_color = Color.TRANSPARENT;
		panel.add_theme_stylebox_override("panel", stylebox);
		stylebox_array.append(stylebox);
		beat_visual.add_child(panel);
	
	beat_visual_stylebox_array = stylebox_array;

## 测试bpm的按钮点击
func tap_beat_tester():
	
	var now_time = get_time();
	
	# 距离上次点超过两秒 重开
	if now_time - tester_last_tap > 2:
		tester_last_tap = now_time;
		tester_start_tap = now_time;
		tester_beats = 0;
		buttonSound.button_pressed = false;
		return;
	
	tester_last_tap = now_time;
	tester_beats += 1;
	
	if tester_beats > 1:
		set_bpm(roundi(60.0 / ((now_time - tester_start_tap)/tester_beats) ));
	
	if tester_beats == 10:
		reset_beat();
		buttonSound.button_pressed = true;
	
	tester.create_tween().tween_property(tester, "modulate:v", 1.0, 0.5
		).from(0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC);


func get_time() -> float:
	return Time.get_unix_time_from_system();
