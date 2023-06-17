extends Control

@onready var text := $Text;

@onready var metronome := $Metronome as Metronome;

@onready var buttonSwitch := $ButtonSwitch;

@onready var buttonRandom := $Buttons/HBox/ButtonRandom;
@onready var buttonLoop := $Buttons/HBox/ButtonLoop;
@onready var buttonContinue := $Buttons/HBox/ButtonContinue;

@onready var spinPlayTimes := $Settings/HBox/SpinPlayTimes;

@onready var score := $Score;
@onready var score_panel := $Score/Panel;
@onready var score_panel_box := $Score/Panel/HBox;

@onready var sound_snare := preload("res://audio/snare.wav");

## 是否开启
var enabled := false;

## 一段(一次生成)的长度
const total_length :float = 8;

## 所有的音符，名字:Note
var notes := {
};

## 根据时间索引的音符
var length_notes := {}

## 当前音符
var current_notes := [];

## 开始播放节奏的时间
var time_start_play :float = 0.0;
## 当前打拍时间
var current_beats := [];
## 当前打拍到哪个了
var current_beat_index :int = -1;
## 打了几次了
var played_time :int = 0;

class Note:
	
	var name :String;
	var total_time :float;
	var time_beat :Array;
	var texture :CompressedTexture2D;
	
	func _init(_name: String, _total_time: float, _time_beat: Array, _texture: CompressedTexture2D):
		name = _name;
		total_time = _total_time;
		time_beat = _time_beat;
		texture = _texture;
	
	func _to_string() -> String:
		return "Note: %s total_time=%f, time_beat=%s" % [name, total_time, str(time_beat)];


func _ready():
	
	text.meta_clicked.connect(func(meta):
		OS.shell_open(str(meta))
	);
	text.text = tr("Main/Text");
	
	buttonSwitch.pressed.connect(func():
		var flag :bool = buttonSwitch.button_pressed;
		if flag: metronome.reset_beat();
		metronome.enabled = flag;
		enabled = flag;
		reset_beat_play();
	);
	
	var button_press := func(pressed: bool, button: Button):
		button.size_flags_vertical = SIZE_SHRINK_END if pressed else SIZE_FILL;
	buttonLoop.toggled.connect(button_press.bind(buttonLoop));
	buttonContinue.toggled.connect(button_press.bind(buttonContinue));
	
	#spinPlayTimes.get_line_edit().focus_mode = FOCUS_NONE;
	spinPlayTimes.prefix = tr("$playtimes_prefix");
	spinPlayTimes.suffix = tr("$playtimes_suffix");
	
	metronome.beat.connect(beat);
	metronome.spinBox_beat_count.suffix = tr(metronome.spinBox_beat_count.suffix);
	
	load_notes();
	
	buttonRandom.pressed.connect(generate_new_beats);

func generate_new_beats():
	
	score_panel_box.scale = Vector2(1,1);
	
	for node in score_panel_box.get_children():
		score_panel_box.remove_child(node);
		node.queue_free();
	current_notes.clear();
	current_beats.clear();
	var add_time := 0.0;
	var prev_note :Note;
	while add_time < total_length:
		var limit_time = total_length - add_time;
		var available_notes :Array = notes.values().filter(
			func(note: Note):
				if prev_note != null:
					if prev_note.name == "8r" && note.name == "8r":
						return false;
				return note.total_time < 4 && note.total_time <= limit_time;
		)
		var note :Note = available_notes.pick_random();
		current_notes.append(note);
		for time in note.time_beat:
			current_beats.append(add_time + time);
		prev_note = note;
		var rect := TextureRect.new();
		rect.texture = note.texture;
		rect.stretch_mode = TextureRect.STRETCH_KEEP;
		rect.size_flags_vertical = Control.SIZE_SHRINK_END;
		rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL;
		score_panel_box.add_child(rect);
		add_time += note.total_time;
	#print("total_beat = ", add_time);
	#print("beats = ", current_beats);
	
	# 如果生成的太长缩一下
	if score_panel_box.size.x > score_panel.size.x:
		score_panel_box.scale.x = score_panel.size.x/score_panel_box.size.x;
	
	# 播放
	reset_beat_play();


func _process(_delta: float):
	
	if !enabled: return;
	
	# 播放节奏
	var beat_time = 60.0 / metronome.bpm;
	var now = get_time();
	var time_passed = now - time_start_play;
	if time_passed < 0:
		return;
	var index = 0;
	for beat_time_stamp in current_beats:
		if time_passed >= beat_time_stamp * beat_time:
			if index <= current_beat_index:
				index += 1;
				continue;
			play_sound(sound_snare);
			current_beat_index += 1;
	
	if current_beat_index + 1 == current_beats.size() && time_passed >= total_length * beat_time:
		played_time += 1;
		if buttonContinue.button_pressed:
			reset_beat_play();
			if played_time >= spinPlayTimes.value:
				played_time = 0;
				generate_new_beats();
		elif buttonLoop.button_pressed:
			reset_beat_play();

func _input(event: InputEvent):
	match event.get_class():
		"InputEventKey":
			event = event as InputEventKey;
			if event.pressed && !event.is_echo() && event.as_text_keycode() == "Space":
				play_sound(preload("res://audio/drumbass.wav"));

func reset_beat_play():
	current_beat_index = -1;
	time_start_play = get_next_first_beat();

func load_notes():
	var path = "res://image/note/";
	
	for file_name in DirAccess.get_files_at(path):
		
		# 导出后只会列出.import文件, 因此只要删掉这个结尾就是可以load的原路径了
		if !file_name.ends_with(".import"): continue;
		file_name = file_name.substr(0, file_name.rfind("."));
		
		var texture := load(path + file_name);
		var total_time := 0.0;
		var beat_time := [];
		
		var add_time :float = 0.0;
		
		for one_note in file_name.substr(0, file_name.rfind(".")).split("_"):
			
			var number_string := "";
			var end_string :String = "";
			
			for word in one_note.split():
				if word.is_valid_int():
					number_string += word;
				else:
					end_string += word;
			
			var time :float = 4.0/number_string.to_int();
			if end_string == "d": time *= 1.5; #dot 附点
			
			total_time += time;
			
			if end_string != "r": # 如果不是 rest 休止, 这个音符算(上一个音符结束后)发音
				beat_time.append(add_time);
			add_time += time;
		
		file_name = file_name.substr(0, file_name.rfind("."));
		var note = Note.new(file_name, total_time, beat_time, texture);
		
		notes[file_name] = note;
		
		var same_total_time_notes = length_notes.get(total_time);
		if same_total_time_notes == null:
			same_total_time_notes = [];
			length_notes[total_time] = same_total_time_notes;
		same_total_time_notes.append(note);
	
	#print(str(notes).replace(', "', ',\n"'));
	#print(str(length_notes))

func beat():
	var stylebox :StyleBoxFlat = score_panel.get_theme_stylebox("panel");
	var tween = score_panel.create_tween();
	tween.tween_property(stylebox, "bg_color", Color.WHITE, 60.0/metronome.bpm
		).from(Color(1,1,1,0.975)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC);

## 播放声音！
func play_sound(stream: AudioStream, volume: float = 0, pitch: float = 1, bus: String = "Master"):	
	var player = AudioStreamPlayer.new();
	add_child(player);
	player.stream = stream;
	player.volume_db = volume
	player.pitch_scale = pitch;
	player.bus = bus;
	player.finished.connect(func(): player.queue_free());
	player.play();

## 震动动画
func beat_animate(node: CanvasItem, _scale: float = 1.1, time: float = 0.5):
	var v_scale = Vector2(_scale, _scale);
	node._scale = v_scale;
	node.queue_redraw();
	var tween = node.create_tween();
	tween.tween_property(node, "scale", Vector2(1,1), time
		).from(v_scale).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC);


func get_time() -> float:
	return Time.get_unix_time_from_system();
	
func get_next_first_beat() -> float:
	var now = get_time();
	var beat_time = 60.0/metronome.bpm;
	var section_time = metronome.beat_count * beat_time;
	return now + section_time - fmod(now, metronome.last_beat) - (metronome.beat_index - 1) * beat_time;
