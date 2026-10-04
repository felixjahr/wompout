export const MODES = {
  solo_womp_ranked: {
    ranked: true,
    teamCount: 2,
    teamSize: 1,
    trophyChanges: [10, -8],
  },
  duo_womp_ranked: {
    ranked: true,
    teamCount: 2,
    teamSize: 2,
    trophyChanges: [10, -8],
  },
  super_womp_ranked: {
    ranked: true,
    teamCount: 4,
    teamSize: 1,
    trophyChanges: [15, 5, -3, -12],
  },
  womp_draft_unranked: {
    ranked: false,
    teamCount: 2,
    teamSize: 1,
  },
  super_womp_unranked: {
    ranked: false,
    teamCount: 4,
    teamSize: 1,
  },
} as const;

export const DEFAULT_MODE_ID_BY_LOBBY_SIZE: Record<number, keyof typeof MODES> =
  {
    1: 'solo_womp_ranked',
    2: 'duo_womp_ranked',
    3: 'super_womp_unranked',
    4: 'super_womp_unranked',
  };

export const MAX_LOBBY_PLAYERS = 4;

export const MATCHMAKING_TIMEOUT_MS = 10000;

export const MAPS = ['forest', 'mountains'];
