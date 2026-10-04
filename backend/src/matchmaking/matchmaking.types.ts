import { MODES } from '../config/modes.config';

export interface MatchmakingPlayer {
  id: string;
  displayName: string;
  loadout: {
    rangedId: string;
    meleeId: string;
    armourId: string;
    abilityId: string;
  };
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
