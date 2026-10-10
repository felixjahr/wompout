import { PlayerLoadout } from '../players/players.types';

export interface GameBot {
  id: string;
  displayName: string;
  teamId: number;
  loadout: PlayerLoadout;
}

export interface GamePlayer {
  id: string;
  displayName: string;
  teamId: number;
  loadout: PlayerLoadout;
}

export interface GameSpec {
  id: string;
  modeId: string;
  mapId: string;
  players: GamePlayer[];
  bots: GameBot[];
}

export interface Game {
  id: string;
  modeId: string;
  mapId: string;
  players: GamePlayer[];
  bots: GameBot[];
  ip: string;
  port: number;
  playerTokens: Record<string, string>;
  callbackTokenHash: string;
  startupTimer?: ReturnType<typeof setTimeout>;
  status: 'starting' | 'ready' | 'failed';
}

export interface CompletedGame {
  id: string;
  callbackTokenHash: string;
  expiresAt: number;
  completionPromise: Promise<void>;
}
