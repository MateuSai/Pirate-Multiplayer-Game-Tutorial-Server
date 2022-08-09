extends Node

const SERVER_PORT: int = 5466

var rooms: Dictionary = {}
var players_room: Dictionary = {}

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
    
    
remote func join_room(room_id: int, info: Dictionary) -> void:
    var sender_id: int = get_tree().get_rpc_sender_id()
    
    _add_player_to_room(room_id, sender_id, info)
    
    
func _add_player_to_room(room_id: int, id: int, info: Dictionary) -> void:
    # Update data structures
    rooms[room_id].players[id] = info
    players_room[id] = room_id
    
    # Send the room id to the new player
    rpc_id(id, "update_room", room_id)
    
    # Notify all connected players (in the room) about it (including the new one)
    for player_id in rooms[room_id].players:
        rpc_id(player_id, "register_player", id, info)
    
    # Send the rest of the players to the new player
    for other_player_id in rooms[room_id].players:
        if other_player_id != id:
            rpc_id(id, "register_player", other_player_id, rooms[room_id].players[other_player_id])
        
        
func _player_connected(id: int) -> void:
    print("Player with id " + str(id) + " connected")
    
    
func _player_disconnected(id: int) -> void:
    print("Player with id " + str(id) + " disconnected")
    
    if not players_room.keys().has(id):
        # The player was not in any room.
        print("Player was not in any room yet")
        return
        
    var room_id: int = players_room[id]
    
    if not rooms[room_id].players.erase(id) or not players_room.erase(id):
        printerr("This key does not exist")
        
    if rooms[room_id].players.size() == 0:
        # Close the room
        print("Closing room " + str(room_id))
        
        if not rooms.erase(room_id):
            printerr("Error removing room")
        empty_rooms.push_back(room_id)
    else:
        # Notify the other players of the room
        print("Notifying the other players in the room...")
        
        for player_id in rooms[room_id].players:
            rpc_id(player_id, "remove_player", id)
