# Smash Dash

Smash Dash is a multiplayer platform fighter built with Godot and a TypeScript backend. Players enter an arena, draft a unique loadout of weapons, armour, and abilities, then fight in fast 2D platform combat.

The project is designed as a complete game stack: a Godot client, a dedicated Godot game server, and a NestJS backend for accounts, rooms, authentication, and match startup. The game is available on both iOS and Android.

<p>
  <a href="https://apps.apple.com/app/smash-dash/id6769724763">App Store</a>
  &nbsp;|&nbsp;
  <a href="https://play.google.com/store/apps/details?id=com.felixjahr.smashdash">Google Play</a>
</p>

## Gameplay

- **Platform fighter combat** with movement, jumping, aiming, melee attacks, ranged attacks, and abilities.
- **Draft-based loadouts** where each player chooses between item pairs before the fight starts.
- **Item variety** across melee weapons, ranged weapons, armour, and active abilities.
- **Arena maps** with themed environments such as forest and mountains.
- **Real-time multiplayer** using a dedicated authoritative Godot server.

## Technical Highlights

- **Godot 4.6 game client** with reusable scenes for players, maps, UI, bullets, draft screens, and gameplay state.
- **Authoritative game server** using Godot's ENet multiplayer API for low-latency real-time synchronization.
- **Snapshot networking** for server-to-client game state updates and batched player input handling.
- **NestJS backend** for guest authentication, JWT refresh flow, room creation, room joining, and match lifecycle callbacks.
- **WebSocket room coordination** for authenticated clients and match-start notifications.
- **PostgreSQL persistence through Prisma** for player accounts and refresh sessions.
- **Docker deployment setup** for backend and dedicated game server services.

## Architecture

```text
Godot Client
  | REST: auth, create/join/leave rooms
  | WebSocket: lobby events and match start
  v
NestJS Backend
  | starts and tracks room lifecycle
  | issues game connection data and tokens
  v
Godot Dedicated Server
  | ENet multiplayer
  | validates game tokens
  | receives input batches
  | sends snapshots and state sync
  v
Arena Fight
```

## Repository Structure

```text
.
+-- backend/              # NestJS API, WebSocket gateway, auth, rooms, Prisma
+-- deploy/               # Dockerfiles and compose/deployment scripts
+-- godot/                # Godot project, client, server, gameplay, UI, data
|   +-- client/           # Client-side networking and controller scenes
|   +-- server/           # Dedicated game server networking/controller
|   +-- games/            # Draft phase and fight logic
|   +-- data/             # Maps, weapons, armour, abilities
|   +-- packets/          # Snapshot, input, and state sync packet types
|   +-- ui/               # Menus, lobby, draft, overlay, game over screens
+-- assets/               # Source art/assets
```

## Tech Stack

| Area | Technology |
| --- | --- |
| Game engine | Godot 4.6, GDScript |
| Multiplayer gameplay | Godot ENet, RPCs, authoritative server |
| Backend API | NestJS, TypeScript |
| Realtime lobby | WebSockets |
| Database | PostgreSQL |
| ORM | Prisma |
| Deployment | Docker, Docker Compose |

## Features

- Guest account creation and token refresh.
- Room creation, joining, leaving, starting, and ending.
- Authenticated lobby WebSocket connection.
- Dedicated server token validation for match access.
- Draft phase with automatic fallback picks after a time limit.
- Server-driven fight state with client snapshot updates.
- Multiple item categories: melee, ranged, armour, and abilities.
- Mobile-oriented project settings with touch emulation support.
