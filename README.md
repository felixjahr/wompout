# Wompout

Wompout is a multiplayer platform fighter for iOS and Android, built with Godot and a TypeScript backend. Players combine weapons, armour, and abilities, then compete in ranked duels, team battles, free-for-all matches, or a draft mode where each pick also determines the opponent's equipment.

The project implements a complete game stack: a mobile Godot client, authoritative dedicated game servers, and a NestJS backend for accounts, matchmaking, social features, and persistent progression. It brings together gameplay programming, custom network protocols, transactional database operations, and container orchestration.

<p>
  <a href="https://apps.apple.com/app/smash-dash/id6769724763">App Store</a>
  &nbsp;|&nbsp;
  <a href="https://play.google.com/store/apps/details?id=com.felixjahr.smashdash">Google Play</a>
  &nbsp;|&nbsp;
  <a href="https://wompout.com">Website</a>
</p>

## Gameplay

- **Platform fighter combat** with movement, jumping, aiming, melee and ranged attacks, knockback, and active abilities.
- **Multiple game modes** including ranked Solo Womp (1v1), Duo Womp (2v2), Super Womp (four-player free-for-all), and unranked matches, with game-mode switching from the lobby.
- **Draft phase** with automatic fallback picks after a time limit.
- **Custom equipment** with saved loadouts combining melee weapons, ranged weapons, armour, and abilities such as dashing, double jumping, invisibility, and slam attacks.
- **Arena maps** set in forest and mountain environments.
- **Real-time multiplayer** with friend requests, lobby invitations, party management, and bots that fill remaining matchmaking slots after a timeout.
- **Persistent progression** through ranked trophies, leaderboards, reward chests, equipment unlocks, character colors, an armory, and a shop using earned coins and gems.
- **Mobile controls and feedback** with touch controls for movement and combat, haptic feedback, and match results screens.

## Technical Highlights

- **Godot 4.7 game client** with reusable scenes for players, maps, equipment, menus, touch controls, and gameplay state.
- **Authoritative game server** that owns movement, damage, elimination, and match results. Clients submit player inputs over ENet, while the server validates match tokens and incoming packets.
- **Snapshot networking** with a 30 Hz server simulation, 15 Hz snapshots, client interpolation, and server-clock correction. Custom binary input packets use eight bytes per input, bit-packed action flags, quantized aim, and retransmission of recent inputs.
- **NestJS backend** for guest and email accounts, JWT access tokens, rotating refresh sessions stored as hashes, account linking, and account deletion.
- **WebSocket state coordination** with authenticated subscriptions, initial state snapshots, and subsequent updates for lobbies, invitations, friends, rankings, and matches.
- **Party-aware matchmaking** using backtracking to assemble teams without splitting parties. Each match gets a dedicated Docker container, assigned UDP port, connection credentials, and lifecycle monitoring.
- **PostgreSQL persistence through Prisma** for accounts, friendships, inventory, loadouts, currencies, and chest progression. Shop purchases and chest rewards use transactions; loadout changes validate item ownership.
- **Bot navigation and combat** using cached map geometry and traversal graphs to plan movement, select targets, switch weapons, and activate abilities through the same input structure as human players.
- **Docker deployment setup** for the backend, PostgreSQL, headless Godot servers, and a Caddy HTTPS reverse proxy.

## Architecture

### System Overview

The mobile client connects to NestJS for accounts, parties, and progression, and directly to a dedicated Godot server for gameplay. The backend launches one server container per match. PostgreSQL stores persistent player data, while the backend manages temporary lobby, matchmaking, and match state in memory.

```mermaid
flowchart TD
    Client["Godot mobile client"]
    Proxy["Caddy reverse proxy"]
    API["NestJS backend"]
    DB[(PostgreSQL)]
    Server["Godot server per match"]

    Client <-->|HTTPS and WSS| Proxy
    Proxy <--> API
    API <-->|Prisma| DB
    API -->|Launch match container| Server
    Server -->|Authenticated lifecycle callbacks| API
    Client <-->|ENet over UDP| Server
```

### Match Lifecycle

The backend assembles teams, starts a server, and sends connection details when it is ready. After play, the server reports results before requesting match closure and shutting down.

```mermaid
sequenceDiagram
    participant Client as Godot client
    participant API as NestJS backend
    participant Server as Godot match server
    participant DB as PostgreSQL

    Client->>API: Queue party
    API->>API: Assemble teams
    API->>Server: Launch match container
    Server->>API: Report ready
    API-->>Client: Send server address and player token
    Client->>Server: Authenticate over ENet
    Note over Client,Server: Play match using inputs and snapshots
    Server->>API: Report results
    API->>DB: Save progression
    API-->>Client: Publish match results
    Server->>API: Request match closure
    API-->>Server: Confirm closure
    Note over Server: Shut down after grace period
```

### Gameplay Networking

The server runs the authoritative simulation at 30 Hz and sends snapshots at 15 Hz. Clients send batched inputs and interpolate received snapshots for display. Input batches resend up to three recent inputs to tolerate packet loss. Gameplay uses ENet over UDP, with unreliable snapshots and reliable initialization and phase changes.

```mermaid
flowchart LR
    A["Client A<br/>Input batching and interpolation"]
    Server["Dedicated Godot server<br/>30 Hz authoritative simulation"]
    B["Client B<br/>Input batching and interpolation"]

    A -->|Batched inputs| Server
    Server -->|15 Hz snapshots| A
    Server -->|15 Hz snapshots| B
    B -->|Batched inputs| Server
```

## Repository Structure

```text
.
+-- backend/              # NestJS API, authentication, matchmaking, social features
|   +-- src/              # Services, controllers, WebSocket gateway, tests
|   +-- prisma/           # PostgreSQL schema
|   +-- Dockerfile        # Backend build and runtime image
+-- godot/                # Godot project, client, dedicated server, game assets
|   +-- client/           # Client state machine and backend/game connections
|   +-- server/           # Dedicated server controller and networking
|   +-- data/             # Game modes, maps, weapons, armour, abilities, styles
|   +-- participant/      # Player simulation, presentation, and bot behavior
|   +-- packets/          # Binary input, snapshot, and state sync packets
|   +-- ui/               # Authentication, menus, lobby, HUD, and results
|   +-- Dockerfile        # Headless Godot server export and runtime image
+-- docker-compose.yml    # Backend, database, game-server image, reverse proxy
+-- Caddyfile             # HTTPS and invitation-domain routing
```

## Tech Stack

| Area | Technology |
| --- | --- |
| Game engine | Godot 4.7, GDScript |
| Multiplayer gameplay | ENet, RPCs, authoritative simulation, binary packets |
| Backend API | NestJS, TypeScript, Node.js |
| Realtime coordination | WebSockets, RxJS |
| Database | PostgreSQL |
| ORM | Prisma |
| Email delivery | Resend |
| Deployment | Docker, Docker Compose, Caddy |

## Code References

- **Gameplay networking** combines compact binary inputs in [input_batch.gd](godot/packets/input/input_batch.gd) with snapshot interpolation and clock correction in [logic_client.gd](godot/data/modes/logic_client.gd).
- **Party-aware matchmaking** in [matchmaking.service.ts](backend/src/matchmaking/matchmaking.service.ts) uses backtracking to fill teams without splitting parties, with bots filling open slots after a timeout.
- **Realtime subscriptions** in [realtime.service.ts](backend/src/realtime/realtime.service.ts) use typed snapshot providers and per-connection queues, retrying setup when state changes during loading.
- **Client–backend authentication** pairs shared token refresh and WebSocket reauthentication in [client_backend_net.gd](godot/client/client_backend_net.gd) with hashed refresh tokens and atomic rotation in [sessions.service.ts](backend/src/sessions/sessions.service.ts).
