import type { Player } from '../players/players.types';
import type { Lobby, LobbyInviteSnapshot } from '../lobbies/lobbies.types';
import type { Friends } from '../friends/friends.types';
import type { Match } from '../matches/matches.types';
import type { Rankings } from '../rankings/rankings.types';
import type { Shop } from '../shop/shop.types';

export enum ResourceName {
  Player = 'player',
  Lobby = 'lobby',
  LobbyInvites = 'lobbyInvites',
  Friends = 'friends',
  Match = 'match',
  Rankings = 'rankings',
  Shop = 'shop',
}

export interface Resources {
  [ResourceName.Player]: Player;
  [ResourceName.Lobby]: Lobby;
  [ResourceName.LobbyInvites]: LobbyInviteSnapshot[];
  [ResourceName.Friends]: Friends;
  [ResourceName.Match]: Match | null;
  [ResourceName.Rankings]: Rankings;
  [ResourceName.Shop]: Shop;
}

export type SnapshotProvider<R extends ResourceName> = (
  playerId: string,
) => Resources[R] | Promise<Resources[R]>;

export type ClientMessage =
  | {
      event: 'authenticate';
      data: {
        requestId: string;
        accessToken: string;
      };
    }
  | {
      event: 'subscribe' | 'unsubscribe';
      data: {
        requestId: string;
        resources: ResourceName[];
      };
    };

export type ServerMessage =
  | {
      event: 'authenticated';
      data: {
        requestId: string;
      };
    }
  | {
      event: 'subscribed';
      data: {
        requestId: string;
        snapshots: Partial<Resources>;
      };
    }
  | {
      event: 'unsubscribed';
      data: {
        requestId: string;
        resources: ResourceName[];
      };
    }
  | StateMessage
  | {
      event: 'error';
      data: {
        requestId: string | null;
        message: string;
      };
    };

export type StateMessage = {
  [R in ResourceName]: {
    event: 'state';
    data: {
      resource: R;
      snapshot: Resources[R];
    };
  };
}[ResourceName];
