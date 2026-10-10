import { MODES } from '../config/modes.config';
import { PlayerLoadout } from '../players/players.types';

export interface MatchmakingPlayer {
  id: string;
  displayName: string;
  loadout: PlayerLoadout;
}

export interface MatchmakingTicket {
  id: string;
  lobbyId: string;
  modeId: keyof typeof MODES;
  players: MatchmakingPlayer[];
  timeoutTimer: ReturnType<typeof setTimeout>;
}

export type MatchmakingTeam = MatchmakingPlayer[];

export type MatchmakingPlan = {
  tickets: MatchmakingTicket[];
  teams: MatchmakingTeam[];
};
