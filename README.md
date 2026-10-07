# Ashen Vale client

A Godot 4 client-side MMORPG skeleton using original placeholder visuals and setting. This is an independent project inspired by classic 2D fantasy RPGs; it does not reproduce or include original game assets or text.

## Requirements and launch

- Godot 4.x (the project uses the Compatibility renderer)
- No third-party addons or packages

Open `project.godot` in Godot 4 and press **F6** to run the current scene or **F5** to launch the project. The configured main scene is `scenes/login.tscn`. The project uses portable GDScript and Godot's Compatibility renderer for Windows and Linux.

For standalone builds, install the matching Godot export templates, then use **Project → Export** to add a Windows Desktop or Linux/X11 preset and export. The client has no platform-specific code.

## Scene flow

1. **Login / Connect** — enter a WebSocket server URL (`ws://` or `wss://`) and character name. The client starts a connection attempt and opens character creation.
2. **Character creation** — answer five original multiple-choice questions. Each question has four attribute-specific choices (Power, Agility, Endurance, Insight) and one neutral choice. **Reroll Questionnaire** restarts the sequence and clears its attribute totals. Confirming stores the summary and opens the game.
3. **In game** — move the placeholder character with arrow keys or WASD. The screen includes a tile-based placeholder map, HP/MP bars, local chat input, and an empty satchel panel.

The login screen is usable without a running server. Network connection status and server-side character creation are intentionally stubbed while the client and server protocol is developed in parallel.

## WebSocket message shape

Messages are UTF-8 JSON objects with a required string `type` and a `payload` object:

```json
{
  "type": "client_hello",
  "payload": {
    "character_name": "Wayfarer"
  }
}
```

The client sends `client_hello` once the WebSocket reaches the open state. In-game chat sends:

```json
{
  "type": "chat_message",
  "payload": {
    "text": "Hello, traveler."
  }
}
```

Incoming messages with the same `{ "type": "...", "payload": { ... } }` shape are logged for now; gameplay protocol handling is not implemented. The shared `NetworkClient.send_message(type, payload)` method is available for later message types.
