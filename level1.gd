extends Node3D

const LOBBY_NAME = "Main Lobby"
const LOBBY_PASSWORD = ""


func _short(client_id: int) -> String:
	return str(client_id % 100000)

# Player management
var players: Dictionary = { } # _client_id -> Player instance
var local_players: Dictionary = { } # _client_id -> is_local (bool)
var player_scene = preload("res://Player/player.tscn")
var _default_spawn_position: Vector3 = Vector3(5.28188, 1.54939, 37.9693)

var _local_player: Player = null
var _game_instance: String = ""
var _client_id_label: Label = null
var _instance_id_label: Label = null
var _is_local_label: Label = null

var _client_id: int = -1 # Host-


func _ready():
	# Arg parsing
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--instance="):
			_game_instance = arg.split("=")[1]
			break

	# Spawn local player immediately so gameplay isn't blocked by network
	_spawn_local_player()

	# Create client ID display
	_setup_client_id_display()

	# GDSync signals
	GDSync.connected.connect(on_connected)
	GDSync.connection_failed.connect(on_connection_failed)
	# Lobby signals
	GDSync.lobby_received.connect(_on_lobby_received)
	GDSync.lobby_created.connect(_on_lobby_created)
	GDSync.lobby_creation_failed.connect(_on_lobby_creation_failed)
	GDSync.lobby_joined.connect(_on_lobby_joined)
	GDSync.lobby_join_failed.connect(_on_lobby_join_failed)
	# Client join/leave signals
	GDSync.client_joined.connect(_on_client_joined)
	GDSync.client_left.connect(_on_client_left)

	# Use local multiplayer for testing, or regular multiplayer for production
	if OS.is_debug_build():
		GDSync.start_local_multiplayer()
	else:
		GDSync.start_multiplayer()


func _spawn_local_player():
	_local_player = player_scene.instantiate()
	add_child(_local_player)
	_local_player.position = _default_spawn_position


func on_connected():
	_client_id = GDSync.get_client_id() # window client id
	print("[", _short(_client_id), "] Connected to GDSync.")

	_local_player.name = "Player_" + str(_client_id)
	_local_player.set_client_id(_client_id)
	players[_client_id] = _local_player
	local_players[_client_id] = true
	GDSync.set_gdsync_owner(_local_player, _client_id)
	_local_player.position_synchronizer._update_sync_mode()

	_update_client_id_display()

	GDSync.get_public_lobby(LOBBY_NAME)


func _on_lobby_received(lobby: Dictionary):
	# If in debug/local mode, and this is instance 2, always join the lobby
	if OS.is_debug_build() and _game_instance == "2":
		print("[", _short(_client_id), "] Joining lobby: " + LOBBY_NAME)
		GDSync.lobby_join(LOBBY_NAME, LOBBY_PASSWORD)
		return

	if lobby.is_empty():
		print("[", _short(_client_id), "] Lobby not found. Creating lobby: " + LOBBY_NAME)
		GDSync.lobby_create(LOBBY_NAME, LOBBY_PASSWORD, true, 4, { })
	else:
		print("[", _short(_client_id), "] Lobby found. Joining lobby: " + LOBBY_NAME)
		GDSync.lobby_join(LOBBY_NAME, LOBBY_PASSWORD)


func _on_lobby_created(lobby_name: String):
	print("[", _short(_client_id), "] Successfully created lobby: " + lobby_name)
	GDSync.lobby_join(LOBBY_NAME, LOBBY_PASSWORD)


func _on_lobby_creation_failed(lobby_name: String, error: int):
	match (error):
		ENUMS.LOBBY_CREATION_ERROR.LOBBY_ALREADY_EXISTS:
			push_error("A lobby with the name " + lobby_name + " already exists.")
			# Try to join it instead
			GDSync.lobby_join(LOBBY_NAME, LOBBY_PASSWORD)
		ENUMS.LOBBY_CREATION_ERROR.NAME_TOO_SHORT:
			push_error(lobby_name + " is too short.")
		ENUMS.LOBBY_CREATION_ERROR.NAME_TOO_LONG:
			push_error(lobby_name + " is too long.")
		ENUMS.LOBBY_CREATION_ERROR.PASSWORD_TOO_LONG:
			push_error("The password for " + lobby_name + " is too long.")
		ENUMS.LOBBY_CREATION_ERROR.TAGS_TOO_LARGE:
			push_error("The tags have exceeded the 2048 byte limit.")
		ENUMS.LOBBY_CREATION_ERROR.DATA_TOO_LARGE:
			push_error("The data have exceeded the 2048 byte limit.")
		ENUMS.LOBBY_CREATION_ERROR.ON_COOLDOWN:
			push_error("Please wait a few seconds before creating another lobby.")


func _on_lobby_joined(lobby_name: String):
	print("[", _short(_client_id), "] Successfully joined lobby: " + lobby_name)

	# Spawn remote players for all existing clients (our local player is already spawned)
	for client_id in GDSync.lobby_get_all_clients():
		if client_id == _client_id:
			continue # Skip ourselves, local player already exists
		if players.has(client_id):
			print("[", _short(_client_id), "] Player for client ", _short(client_id), " already exists")
		else:
			print("[", _short(_client_id), "] Spawning remote player for client ", _short(client_id))
			_spawn_remote_player(client_id)


func _on_lobby_join_failed(lobby_name: String, error: int):
	match (error):
		ENUMS.LOBBY_JOIN_ERROR.LOBBY_DOES_NOT_EXIST:
			push_error("Lobby " + lobby_name + " does not exist.")
		ENUMS.LOBBY_JOIN_ERROR.LOBBY_IS_CLOSED:
			push_error("Lobby " + lobby_name + " is closed.")
		ENUMS.LOBBY_JOIN_ERROR.LOBBY_IS_FULL:
			push_error("Lobby " + lobby_name + " is full.")
		ENUMS.LOBBY_JOIN_ERROR.INCORRECT_PASSWORD:
			push_error("Incorrect password for lobby " + lobby_name + ".")
		ENUMS.LOBBY_JOIN_ERROR.DUPLICATE_USERNAME:
			push_error("A player with your username is already in the lobby.")


func _on_client_joined(client_id: int):
	print("[", _short(_client_id), "] Client joined: ", _short(client_id))
	if _client_id != client_id and not players.has(client_id):
		_spawn_remote_player(client_id)


func _on_client_left(client_id: int):
	print("[", _short(_client_id), "] Client left: ", _short(client_id))
	if players.has(client_id):
		var player_instance = players[client_id]
		if is_instance_valid(player_instance):
			player_instance.queue_free()
		players.erase(client_id)
		local_players.erase(client_id)


func _spawn_remote_player(client_id: int):
	if players.has(client_id):
		return

	var player_instance = player_scene.instantiate()
	player_instance.name = "Player_" + str(client_id)
	add_child(player_instance)
	players[client_id] = player_instance
	player_instance.position = _default_spawn_position
	player_instance.set_client_id(client_id)
	local_players[client_id] = false
	GDSync.set_gdsync_owner(player_instance, client_id)
	player_instance.position_synchronizer._update_sync_mode()
	print("[", _short(_client_id), "] Spawned remote player for client ", _short(client_id))


func _setup_client_id_display():
	# Create a CanvasLayer for UI overlay
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "ClientIDCanvasLayer"
	add_child(canvas_layer)

	# Create a Control node that covers the screen
	var control = Control.new()
	control.name = "ClientIDControl"
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(control)

	# Create a MarginContainer for positioning in top right
	var margin_container = MarginContainer.new()
	margin_container.name = "ClientIDMarginContainer"
	margin_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin_container.add_theme_constant_override("margin_top", 8)
	margin_container.add_theme_constant_override("margin_right", 8)
	control.add_child(margin_container)

	# Create a VBoxContainer to align content to the top
	var vbox = VBoxContainer.new()
	vbox.name = "ClientIDVBox"
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	margin_container.add_child(vbox)

	# Create the Client ID Label
	_client_id_label = Label.new()
	_client_id_label.name = "ClientIDLabel"
	_client_id_label.text = "Client ID: -"
	_client_id_label.add_theme_font_size_override("font_size", 16)
	_client_id_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(_client_id_label)

	# Create the Instance ID Label
	_instance_id_label = Label.new()
	_instance_id_label.name = "InstanceIDLabel"
	_instance_id_label.text = "Instance: -"
	_instance_id_label.add_theme_font_size_override("font_size", 16)
	_instance_id_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(_instance_id_label)

	# Create the Is Local Label
	_is_local_label = Label.new()
	_is_local_label.name = "IsLocalLabel"
	_is_local_label.text = "Is Local: -"
	_is_local_label.add_theme_font_size_override("font_size", 16)
	_is_local_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(_is_local_label)

	# Update the display with initial client ID
	_update_client_id_display()


func _update_client_id_display():
	if _client_id_label == null:
		return

	_client_id_label.text = "Client ID: " + str(_client_id)

	if _instance_id_label != null:
		var instance_text = _game_instance if _game_instance != "" else "-"
		_instance_id_label.text = "Instance: " + instance_text

	if _is_local_label != null:
		var is_local_text = "-"
		if players.has(_client_id) and is_instance_valid(players[_client_id]):
			is_local_text = str(players[_client_id].is_local_player)
		_is_local_label.text = "Is Local: " + is_local_text


func on_connection_failed(error: int):
	match (error):
		ENUMS.CONNECTION_FAILED.INVALID_PUBLIC_KEY:
			push_error("The public or private key you entered were invalid.")
		ENUMS.CONNECTION_FAILED.TIMEOUT:
			push_error("Unable to connect, please check your internet connection.")
