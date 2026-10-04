export interface Room {
  code: string;
  members: string[];
  gameId: string;
  mapId: string;
  status: 'waiting' | 'starting' | 'ready' | 'failed';
  port?: number;
  ip?: string;
  gameTokens?: Record<string, string>;
  playerNames?: Record<string, string>;
  startupTimer?: ReturnType<typeof setTimeout>;
}
