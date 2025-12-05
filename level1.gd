extends Node3D

const LOBBY_NAME = "Main Lobby"
const LOBBY_PASSWORD = ""

func _ready():
	print("Level 1 ready")
	GDSync.connected.connect(connected)
	GDSync.connection_failed.connect(connection_failed)
	
	# Lobby signals
	GDSync.lobby_received.connect(_on_lobby_received)
	GDSync.lobby_created.connect(_on_lobby_created)
	GDSync.lobby_creation_failed.connect(_on_lobby_creation_failed)
	GDSync.lobby_joined.connect(_on_lobby_joined)
	GDSync.lobby_join_failed.connect(_on_lobby_join_failed)
	
	GDSync.start_multiplayer()

func connected():
	print("You are now connected!")
	# Search for the lobby
	GDSync.get_public_lobby(LOBBY_NAME)

func connection_failed(error : int):
	match(error):
		ENUMS.CONNECTION_FAILED.INVALID_PUBLIC_KEY:
			push_error("The public or private key you entered were invalid.")
		ENUMS.CONNECTION_FAILED.TIMEOUT:
			push_error("Unable to connect, please check your internet connection.")

func _on_lobby_received(lobby : Dictionary):
	print("Lobby received: ", lobby)
	# Check if lobby exists (empty dictionary means it doesn't exist)
	if lobby.is_empty():
		print("Lobby not found. Creating lobby: " + LOBBY_NAME)
		# Create the lobby
		GDSync.lobby_create(
			LOBBY_NAME,
			LOBBY_PASSWORD,
			true,  # public
			0,     # player_limit (0 = auto)
			{}     # tags
		)
	else:
		print("Lobby found. Joining lobby: " + LOBBY_NAME)
		# Join the existing lobby
		GDSync.lobby_join(LOBBY_NAME, LOBBY_PASSWORD)

func _on_lobby_created(lobby_name : String):
	print("Successfully created lobby: " + lobby_name)
	# Now join the newly created lobby
	GDSync.lobby_join(LOBBY_NAME, LOBBY_PASSWORD)

func _on_lobby_creation_failed(lobby_name : String, error : int):
	match(error):
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

func _on_lobby_joined(lobby_name : String):
	print("Successfully joined lobby: " + lobby_name)

func _on_lobby_join_failed(lobby_name : String, error : int):
	match(error):
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
