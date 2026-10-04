import { Friends } from '../friends/friends.types';
import type { Lobby } from '../lobbies/lobbies.types';
import { Player } from '../players/players.types';

export type RealtimeGatewayEvents = {
  playerUpdated: {
    player: Player;
  };

  lobbyUpdated: {
    lobby: Lobby;
  };
  friendsUpdated: {
    friends: Friends;
  };
  gameReady: {
    ip: string;
    port: number;
    playerToken: string;
  };
  gameOver: {
    gameId: string;
    results: {
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
    }[];
  } & (
    | {
        ranked: true;
        trophyChange: number;
      }
    | {
        ranked: false;
        trophyChange?: never;
      }
  );
  gameFailed: {
    reason: string;
  };
};
