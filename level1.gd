extends Node3D

const LOBBY_NAME = "Main Lobby"
const LOBBY_PASSWORD = ""

# Player management
var players: Dictionary = { } # client_id -> Player instance
var local_players: Dictionary = { } # client_id -> is_local (bool)
var player_scene = preload("res://Player/player.tscn")
var _default_spawn_position: Vector3 = Vector3.ZERO

var _initial_player: Player = null
var _game_instance: String = ""
var _client_id_label: Label = null
var _instance_id_label: Label = null
var _is_local_label: Label = null


func _ready():
	# GDSync signals
	GDSync.connected.connect(connected)
	GDSync.connection_failed.connect(connection_failed)
	# Lobby signals
	GDSync.lobby_received.connect(_on_lobby_received)
	GDSync.lobby_created.connect(_on_lobby_created)
	GDSync.lobby_creation_failed.connect(_on_lobby_creation_failed)
	GDSync.lobby_joined.connect(_on_lobby_joined)
	GDSync.lobby_join_failed.connect(_on_lobby_join_failed)
	# Client join/leave signals
	GDSync.client_joined.connect(_on_client_joined)
	GDSync.client_left.connect(_on_client_left)

	# Arg parsing
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--instance="):
			_game_instance = arg.split("=")[1]
			break

	# Initial player setup
	_initial_player = get_node_or_null("Player")
	if _initial_player:
		_default_spawn_position = _initial_player.position
	else:
		_default_spawn_position = Vector3.ZERO

	# Create client ID display
	_setup_client_id_display()

	# Use local multiplayer for testing, or regular multiplayer for production
	if OS.is_debug_build():
		GDSync.start_local_multiplayer() # For local testing
	else:
		GDSync.start_multiplayer() # For production


func connected():
	var client_id = GDSync.get_client_id() if GDSync.is_active() else -1
	print("[Client ID: ", client_id, "] You are now connected!")
	_update_client_id_display()
	# Search for the lobby
	GDSync.get_public_lobby(LOBBY_NAME)


func _on_lobby_received(lobby: Dictionary):
	var client_id = GDSync.get_client_id() if GDSync.is_active() else -1

	# If in debug/local mode, and this is instance 2, always join the lobby,
	# even if it is not found
	if OS.is_debug_build() and _game_instance == "2":
		print("[Client ID: ", client_id, "] [DEBUG] Instance 2 always joins (local debug mode). Joining lobby: " + LOBBY_NAME)
		GDSync.lobby_join(LOBBY_NAME, LOBBY_PASSWORD)
		return

	if lobby.is_empty():
		print("[Client ID: ", client_id, "] Lobby not found. Creating lobby: " + LOBBY_NAME)
		# Create the lobby
		GDSync.lobby_create(
			LOBBY_NAME,
			LOBBY_PASSWORD,
			true, # public
			0, # player_limit (0 = auto)
			{ }, # tags
		)
	else:
		print("[Client ID: ", client_id, "] Lobby found. Joining lobby: " + LOBBY_NAME)
		# Join the existing lobby
		GDSync.lobby_join(LOBBY_NAME, LOBBY_PASSWORD)


func _on_lobby_created(lobby_name: String):
	var client_id = GDSync.get_client_id() if GDSync.is_active() else -1
	print("[Client ID: ", client_id, "] Successfully created lobby: " + lobby_name)
	# Now join the newly created lobby

	# If we have an initial player from the scene, use it and set its client_id
	if _initial_player and is_instance_valid(_initial_player):
		players[client_id] = _initial_player
		_initial_player.set_client_id(client_id)
		local_players[client_id] = _initial_player.is_local_player

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
	var cur_client_id = GDSync.get_client_id() if GDSync.is_active() else -1
	print("[Client ID: ", cur_client_id, "] Successfully joined lobby: " + lobby_name)
	# Spawn players for all existing clients (including ourselves)
	# Handles joining a lobby that already has players
	var all_clients = GDSync.lobby_get_all_clients()
	var my_client_id = GDSync.get_client_id() if GDSync.is_active() else -1
	for client_id in all_clients:
		if players.has(client_id):
			print("[Client ID: ", my_client_id, "] Player for client ", client_id, " already exists")
		else:
			print("[Client ID: ", my_client_id, "] Spawning player for client ", client_id)
			_spawn_player_for_client(client_id)


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
	var my_client_id = GDSync.get_client_id() if GDSync.is_active() else -1
	print("[Client ID: ", my_client_id, "] Client joined: ", client_id)
	# Spawn a player for the newly joined client
	_spawn_player_for_client(client_id)


func _on_client_left(client_id: int):
	var my_client_id = GDSync.get_client_id() if GDSync.is_active() else -1
	print("[Client ID: ", my_client_id, "] Client left: ", client_id)
	# Remove the player instance when a client leaves
	if players.has(client_id):
		var player_instance = players[client_id]
		if is_instance_valid(player_instance):
			player_instance.queue_free()
		players.erase(client_id)
		local_players.erase(client_id)


func _spawn_player_for_client(client_id: int):
	# Don't spawn if player already exists
	var my_client_id = GDSync.get_client_id() if GDSync.is_active() else -1
	if players.has(client_id):
		print("[Client ID: ", my_client_id, "] Player for client ", client_id, " already exists")
		return

	# Instantiate the player scene
	var player_instance = player_scene.instantiate()
	add_child(player_instance)
	players[client_id] = player_instance

	player_instance.position = _default_spawn_position
	player_instance.set_client_id(client_id)
	local_players[client_id] = player_instance.is_local_player

	my_client_id = GDSync.get_client_id() if GDSync.is_active() else -1
	var pos_str = str(_default_spawn_position)
	print(
		"[Client ID: ",
		my_client_id,
		"] Spawned player for client ",
		client_id,
		" at position ",
		pos_str,
	)

	_update_client_id_display()


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

	var client_id = GDSync.get_client_id() if GDSync.is_active() else -1
	_client_id_label.text = "Client ID: " + str(client_id)

	if _instance_id_label != null:
		var instance_text = _game_instance if _game_instance != "" else "-"
		_instance_id_label.text = "Instance: " + instance_text

	if _is_local_label != null:
		var is_local_text = "-"
		if players.has(client_id) and is_instance_valid(players[client_id]):
			is_local_text = str(players[client_id].is_local_player)
		_is_local_label.text = "Is Local: " + is_local_text


func connection_failed(error: int):
	match (error):
		ENUMS.CONNECTION_FAILED.INVALID_PUBLIC_KEY:
			push_error("The public or private key you entered were invalid.")
		ENUMS.CONNECTION_FAILED.TIMEOUT:
			push_error("Unable to connect, please check your internet connection.")
