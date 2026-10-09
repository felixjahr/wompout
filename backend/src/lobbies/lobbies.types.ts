import { MODES } from '../config/modes.config';
import { PlayerLoadout } from '../players/players.types';

export interface LobbyPlayer {
  id: string;
  displayName: string;
  trophies: number;
  ready: boolean;
  loadout: PlayerLoadout;
}

export interface LobbyInvite {
  id: string;
  sourceLobbyId: string;
  sourcePlayerId: string;
  invitedPlayerId: string;
}

export interface LobbyInviteSnapshot {
  inviteId: string;
  sourcePlayer: {
    id: string;
    displayName: string;
    trophies: number;
  };
}

export interface Lobby {
  id: string;
  modeId: keyof typeof MODES;
  players: LobbyPlayer[];
  status: 'open' | 'matchmaking' | 'in-game';
}
