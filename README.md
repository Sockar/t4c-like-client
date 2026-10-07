# Ashen Vale client

A Godot 4 client for an original 2D fantasy MMORPG prototype. The project uses original SVG art and placeholder UI, with a WebSocket JSON client for the Mosswake Fen server protocol. No original game assets or text are used.

## Requirements and launch

- Godot 4.x (Compatibility renderer)
- No third-party addons or packages

Open `project.godot` and press **F5** to run. Enter a WebSocket URL (`ws://` or `wss://`) and character name, complete the questionnaire, then confirm to connect and enter the game. Windows and Linux are supported through portable GDScript and Godot export templates. To export, install the matching templates and add Windows Desktop or Linux/X11 presets in **Project → Export**.

Run protocol unit checks with:

```sh
godot --headless --path . --scene res://tests/protocol_test.tscn
```

## Character creation

The questionnaire accumulates points for `power`, `agility`, `endurance`, and `insight`. The server requires each attribute to be an integer from 1–10 and the total to equal 20. Before sending `character.create`, the client assigns a base score of 1 to each attribute and proportionally distributes the remaining 16 points according to the questionnaire totals. It uses deterministic largest-remainder rounding, caps each score at 10, and redistributes any capped points to attributes with remaining capacity. If every answer was neutral, the result is 5 in each attribute.

After the WebSocket opens, the client sends `character.create`. If the server returns an `error` before confirming creation, the client falls back once to `auth.login` with the entered name.

## World and UI

The game renders the server's zone dimensions; Mosswake Fen is 100×100 zone units. The 50×50 TileMap uses 32-pixel cells, with each cell covering 2 zone units (16 pixels per server coordinate). Movement sends `position.update` approximately 10 times per second while moving. Server snapshots and deltas drive the local player position and the rendered NPC, monster, and other-player markers.

The client includes:

- Server-driven HP/MP bars, XP display, chat, and quest log.
- Click-selectable markers; Attack and Fire Bolt target the selected or nearest monster within 8 zone units. Heal targets `self`.
- A Talk button or **E** interaction for the nearest NPC within 5 zone units. Server dialogue can present quest acceptance buttons; ready quests show Turn In controls.
- A 12-slot placeholder inventory grid and original SVG sprites/icons.

Attack, spells, chat, dialogue, and quest actions send protocol requests; combat, magic, quest state, dialogue, character stats, and experience are updated from server messages.

## WebSocket envelope and client messages

Messages are UTF-8 JSON objects with a `type` and object-valued `payload`:

```json
{
  "type": "character.create",
  "payload": {
    "name": "Aster",
    "attributes": {
      "power": 5,
      "agility": 5,
      "endurance": 5,
      "insight": 5
    }
  }
}
```

The client sends these protocol messages:

| Type | Payload |
|---|---|
| `auth.login` | `{"name":"Aster"}` — sent only as a character-creation error fallback |
| `character.create` | `{"name":"Aster","attributes":{"power":5,"agility":5,"endurance":5,"insight":5}}` |
| `position.update` | `{"x":12.5,"y":14}` — zone coordinates |
| `chat.send` | `{"message":"Hello!"}` |
| `combat.attack` | `{"target_id":"reedling-01"}` |
| `magic.cast` | `{"spell_id":"fire_ember_bolt","target_id":"lantern-moth-01"}` or `{"spell_id":"fire_cinder_mend","target_id":"self"}` |
| `npc.talk` | `{"npc_id":"npc_elin"}` |
| `quest.accept` | `{"quest_id":"fen_patrol","npc_id":"npc_maela"}` |
| `quest.turn_in` | `{"quest_id":"fen_patrol","npc_id":"npc_maela"}` |

## Server messages handled

- `character.created` and `auth.accepted`: store the character state (`hp`, `max_hp`, `mp`, `max_mp`, `xp`, quests) and update the HUD.
- `world.snapshot`: set zone dimensions and populate players, NPCs, and monsters.
- `world.delta`: merge updated player/monster fields and remove defeated/despawned monsters.
- `chat.message`: append the server's `from` and `message` fields to chat.
- `combat.result` and `magic.result`: show damage/healing numbers, update target health, and update the local character's HP/MP from the response.
- `npc.dialogue`: show the NPC's dialogue and available quest actions.
- `quest.updated`: update quest title, objective, progress, status, and turn-in action.
- `character.xp`: update the XP display.
- `error`: show the server error; if it rejects `character.create`, attempt `auth.login` once.

All server messages use the same `{ "type": "...", "payload": { ... } }` envelope. Unknown or malformed messages are logged and ignored.

## Original art

All art in `assets/` is project-created SVG: the terrain atlas, animated wayfarer spritesheet, action icons, and inventory placeholder. Map markers are drawn from original simple shapes in GDScript.
