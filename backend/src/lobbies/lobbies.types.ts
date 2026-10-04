import { MODES } from '../config/modes.config';

export interface LobbyPlayer {
  id: string;
  displayName: string;
  ready: boolean;
  loadout: {
    rangedId: string;
    meleeId: string;
    armourId: string;
    abilityId: string;
  };
}

export interface LobbyInvite {
  id: string;
  sourceLobbyId: string;
  sourcePlayerId: string;
  invitedPlayerId: string;
}

export interface Lobby {
  id: string;
  modeId: keyof typeof MODES;
  players: LobbyPlayer[];
  status: 'open' | 'matchmaking' | 'in-game';
}
