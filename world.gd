extends Node

@onready var main_menu = $CanvasLayer/MainMenu
@onready var address_entry = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/AddressEntry
@onready var hud = $CanvasLayer/HUD
@onready var health_bar = $CanvasLayer/HUD/HealthBar
@onready var igmusic = $IngameMusic
@onready var menumusic = $MenuMusic
@onready var bg = $CanvasLayer/background

const Player = preload("res://scene/player.tscn")
const PORT = 9999

var enet_peer = ENetMultiplayerPeer.new()
var players = {}  # Pour suivre les joueurs connectés

func _ready():
	menumusic.play()

func _unhandled_input(event):
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()

func _on_host_button_pressed():
	main_menu.hide()
	bg.hide()
	menumusic.stop()
	igmusic.play()
	hud.show()
	
	# Configuration du serveur
	enet_peer.create_server(PORT)
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(remove_player)
	
	# Ajouter l'hôte en tant que premier joueur
	add_player(1)  # L'hôte a toujours l'ID 1

func _on_join_button_pressed():
	main_menu.hide()
	bg.hide()
	menumusic.stop()
	igmusic.play()
	hud.show()
	
	# Configuration du client
	enet_peer.create_client("localhost", PORT)
	multiplayer.multiplayer_peer = enet_peer

func add_player(peer_id):
	# Vérifier si le joueur n'existe pas déjà
	if not players.has(peer_id):
		var player = Player.instantiate()
		player.name = str(peer_id)
		add_child(player)
		players[peer_id] = player
		
		# Connecter le signal de santé seulement pour le joueur local
		if peer_id == multiplayer.get_unique_id():
			player.health_changed.connect(update_health_bar)

func remove_player(peer_id):
	if players.has(peer_id):
		if players[peer_id]:
			players[peer_id].queue_free()
		players.erase(peer_id)

func update_health_bar(health_value):
	health_bar.value = health_value

func _on_multiplayer_spawner_spawned(node):
	if node.is_multiplayer_authority():
		node.health_changed.connect(update_health_bar)
