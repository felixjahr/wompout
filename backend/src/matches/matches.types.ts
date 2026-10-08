export interface MatchResult {
  participantId: string;
  displayName: string;
  teamId: number;
  placement: number;
  loadout: {
    rangedId: string;
    meleeId: string;
    armourId: string;
    abilityId: string;
  };
}

interface MatchBase {
  gameId: string;
  modeId: string;
  mapId: string;
}

export type Match = MatchBase &
  (
    | {
        status: 'starting';
      }
    | {
        status: 'ready';
        connection: {
          ip: string;
          port: number;
          playerToken: string;
        };
      }
    | {
        status: 'completed';
        results: MatchResult[];
        trophyChange: number | null;
      }
    | {
        status: 'failed';
        reason: string;
      }
  );
