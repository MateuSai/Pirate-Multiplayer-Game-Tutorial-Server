extends Node

const SERVER_PORT: int = 5466

var rooms: Dictionary = {}

var next_room_id: int = 0
var empty_rooms: Array = []

enum { WAITING, STARTED }


func _ready() -> void:
    var peer: NetworkedMultiplayerENet = NetworkedMultiplayerENet.new()
    if peer.create_server(SERVER_PORT):
        printerr("Error creating the server")
        get_tree().quit()
    get_tree().network_peer = peer
    
    if get_tree().connect("network_peer_connected", self, "_player_connected"):
        printerr("Error connecting network_peer_connected signal")
        get_tree().quit()
    if get_tree().connect("network_peer_disconnected", self, "_player_disconnected"):
        printerr("Error connecting network_peer_disconnected signal")
        get_tree().quit()
        
        
remote func create_room(info: Dictionary) -> void:
    print("Room created")
    var sender_id: int = get_tree().get_rpc_sender_id()
    
    var room_id: int
    if empty_rooms.empty():
        room_id = next_room_id
        next_room_id += 1
    else:
        room_id = empty_rooms.pop_back()
        
    rooms[room_id] = {
        creator = sender_id,
        players = {},
        players_done = 0,
        state = WAITING,
    }
    
    _add_player_to_room(room_id, sender_id, info)
    
    
func _add_player_to_room(room_id: int, player_id: int, info: Dictionary) -> void:
    rooms[room_id].players[player_id] = info
    
    rpc_id(player_id, "update_room", room_id)
        
        
func _player_connected(id: int) -> void:
    print("Player with id " + str(id) + " connected")
    
    
func _player_disconnected(id: int) -> void:
    print("Player with id " + str(id) + " disconnected")
