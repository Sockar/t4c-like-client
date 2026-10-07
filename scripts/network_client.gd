extends Node

var _socket := WebSocketPeer.new()
var _character_name := ""
var _hello_sent := false
var _connecting := false


func connect_to_server(address: String, character_name: String) -> Error:
	if not address.begins_with("ws://") and not address.begins_with("wss://"):
		return ERR_INVALID_PARAMETER

	close_connection()
	_socket = WebSocketPeer.new()
	_character_name = character_name
	_hello_sent = false
	var error := _socket.connect_to_url(address)
	_connecting = error == OK
	return error


func send_message(message_type: String, payload: Dictionary = {}) -> Error:
	if _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return ERR_UNAVAILABLE

	var message := (
		JSON
		. stringify(
			{
				"type": message_type,
				"payload": payload,
			}
		)
	)
	return _socket.send(message.to_utf8_buffer(), WebSocketPeer.WRITE_MODE_TEXT)


func close_connection() -> void:
	if _socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_socket.close()
	_connecting = false
	_hello_sent = false


func _process(_delta: float) -> void:
	if not _connecting:
		return

	_socket.poll()
	var state := _socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN and not _hello_sent:
		_hello_sent = true
		var error := send_message("client_hello", {"character_name": _character_name})
		if error != OK:
			push_warning("Could not send client_hello: %s" % error_string(error))
	elif state == WebSocketPeer.STATE_CLOSED:
		_connecting = false

	while state == WebSocketPeer.STATE_OPEN and _socket.get_available_packet_count() > 0:
		_handle_packet(_socket.get_packet().get_string_from_utf8())


func _handle_packet(packet_text: String) -> void:
	var message: Variant = JSON.parse_string(packet_text)
	if not message is Dictionary:
		push_warning("Ignoring non-object server message: %s" % packet_text)
		return
	if not message.has("type") or not message.has("payload"):
		push_warning("Ignoring server message without type/payload: %s" % packet_text)
		return
	print("Server message: ", JSON.stringify(message))
