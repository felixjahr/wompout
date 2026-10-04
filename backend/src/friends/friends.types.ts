export interface Friends {
  players: {
    id: string;
    displayName: string;
    trophies: number;
    status: 'offline' | 'open' | 'matchmaking' | 'in-game';
  }[];

  lobbyInvites: {
    inviteId: string;
    sourcePlayerId: string;
    sourceDisplayName: string;
  }[];
}
