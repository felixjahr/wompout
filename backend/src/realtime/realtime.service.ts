import { Injectable } from '@nestjs/common';
import { WsException } from '@nestjs/websockets';
import { WebSocket } from 'ws';
import {
  ResourceName,
  type Resources,
  type ServerMessage,
  type SnapshotProvider,
  type StateMessage,
} from './realtime.types';
import { SessionsService } from '../sessions/sessions.service';

interface Connection {
  identity?: {
    playerId: string;
    sessionId: string;
    expiresAt: number;
  };
  subscriptions: Set<ResourceName>;
  queue: Promise<void>;
  loading?: {
    resources: Set<ResourceName>;
    changed: boolean;
  };
}

type Providers = {
  [R in ResourceName]?: SnapshotProvider<R>;
};

type LifecycleHandler = (playerId: string) => void | Promise<void>;

@Injectable()
export class RealtimeService {
  private readonly connections = new Map<WebSocket, Connection>();
  private readonly socketByPlayerId = new Map<string, WebSocket>();
  private readonly providers: Providers = {};
  private readonly beforeAuthenticatedHandlers: LifecycleHandler[] = [];
  private readonly afterAuthenticatedHandlers: LifecycleHandler[] = [];
  private readonly afterDisconnectedHandlers: LifecycleHandler[] = [];

  constructor(private readonly sessionsService: SessionsService) {}

  registerConnection(client: WebSocket): void {
    this.connections.set(client, {
      subscriptions: new Set(),
      queue: Promise.resolve(),
    });
  }

  unregisterConnection(client: WebSocket): void {
    const connection = this.connections.get(client);
    this.connections.delete(client);

    const playerId = connection?.identity?.playerId;

    if (!playerId || this.socketByPlayerId.get(playerId) !== client) {
      return;
    }

    this.socketByPlayerId.delete(playerId);

    for (const handler of this.afterDisconnectedHandlers) {
      void Promise.resolve()
        .then(() => handler(playerId))
        .catch((error: unknown) => {
          console.error('Disconnect handler failed', error);
        });
    }
  }

  enqueue(
    client: WebSocket,
    operation: () => void | Promise<void>,
  ): Promise<void> {
    const connection = this.getConnection(client);

    const result = connection.queue.then(async () => {
      if (this.connections.get(client) !== connection) return;
      await operation();
    });

    connection.queue = result.catch(() => undefined);
    return result;
  }

  async authenticate(client: WebSocket, accessToken: string): Promise<void> {
    const connection = this.getConnection(client);
    const identity = await this.sessionsService.verifyAccessToken(accessToken);

    if (this.connections.get(client) !== connection) return;

    if (
      connection.identity &&
      (connection.identity.playerId !== identity.playerId ||
        connection.identity.sessionId !== identity.sessionId)
    ) {
      throw new WsException('Reconnect to change accounts or sessions');
    }

    const firstAuthentication = !connection.identity;

    if (firstAuthentication) {
      for (const handler of this.beforeAuthenticatedHandlers) {
        await handler(identity.playerId);
      }
    }

    if (
      this.connections.get(client) !== connection ||
      client.readyState !== WebSocket.OPEN
    ) {
      return;
    }

    const previous = this.socketByPlayerId.get(identity.playerId);

    connection.identity = identity;
    this.socketByPlayerId.set(identity.playerId, client);

    if (previous && previous !== client) {
      this.unregisterConnection(previous);
      previous.close();
    }

    this.send(client, {
      event: 'authenticated',
      data: {},
    });

    if (firstAuthentication) {
      for (const handler of this.afterAuthenticatedHandlers) {
        void Promise.resolve()
          .then(() => handler(identity.playerId))
          .catch((error: unknown) => {
            console.error('After-authentication handler failed', error);
          });
      }
    }
  }

  async subscribe(client: WebSocket, resources: ResourceName[]): Promise<void> {
    const connection = this.getAuthenticatedConnection(client);
    const playerId = connection.identity!.playerId;
    const requested = [...new Set(resources)];

    const loading = {
      resources: new Set(requested),
      changed: false,
    };

    connection.loading = loading;

    try {
      for (let attempt = 0; attempt < 3; attempt++) {
        loading.changed = false;

        const snapshots: Partial<Resources> = {};

        await Promise.all(
          requested.map((resource) =>
            this.loadSnapshot(resource, playerId, snapshots),
          ),
        );

        if (this.connections.get(client) !== connection) return;
        this.getAuthenticatedConnection(client);

        if (loading.changed) continue;

        for (const resource of requested) {
          connection.subscriptions.add(resource);
        }

        this.send(client, {
          event: 'subscribed',
          data: { snapshots },
        });

        return;
      }

      throw new WsException('State changed while loading; please retry');
    } finally {
      connection.loading = undefined;
    }
  }

  unsubscribe(client: WebSocket, resources: ResourceName[]): void {
    const connection = this.getAuthenticatedConnection(client);

    for (const resource of resources) {
      connection.subscriptions.delete(resource);
    }

    this.send(client, {
      event: 'unsubscribed',
      data: { resources },
    });
  }

  registerBeforeAuthenticated(handler: LifecycleHandler): void {
    this.beforeAuthenticatedHandlers.push(handler);
  }

  registerAfterAuthenticated(handler: LifecycleHandler): void {
    this.afterAuthenticatedHandlers.push(handler);
  }

  registerAfterDisconnected(handler: LifecycleHandler): void {
    this.afterDisconnectedHandlers.push(handler);
  }

  registerSnapshotProvider<R extends ResourceName>(
    resource: R,
    provider: NonNullable<Providers[R]>,
  ): void {
    if (this.providers[resource]) {
      throw new Error(`Provider already registered: ${resource}`);
    }

    this.providers[resource] = provider;
  }

  publishToPlayers<R extends ResourceName>(
    resource: R,
    snapshot: Resources[R],
    playerIds: readonly string[],
  ): void {
    for (const playerId of new Set(playerIds)) {
      const client = this.socketByPlayerId.get(playerId);

      if (client) {
        this.publish(client, resource, snapshot);
      }
    }
  }

  publishToSubscribers<R extends ResourceName>(
    resource: R,
    snapshot: Resources[R],
  ): void {
    for (const client of this.socketByPlayerId.values()) {
      this.publish(client, resource, snapshot);
    }
  }

  isPlayerConnected(playerId: string): boolean {
    const client = this.socketByPlayerId.get(playerId);

    if (!client || client.readyState !== WebSocket.OPEN) {
      return false;
    }

    const identity = this.connections.get(client)?.identity;
    return !!identity && identity.expiresAt > Date.now();
  }

  private publish<R extends ResourceName>(
    client: WebSocket,
    resource: R,
    snapshot: Resources[R],
  ): void {
    const connection = this.connections.get(client);

    if (!connection?.identity || connection.identity.expiresAt <= Date.now()) {
      return;
    }

    if (connection.loading?.resources.has(resource)) {
      connection.loading.changed = true;
    }

    if (!connection.subscriptions.has(resource)) return;

    this.send(client, {
      event: 'state',
      data: { resource, snapshot },
    } as StateMessage);
  }

  private async loadSnapshot<R extends ResourceName>(
    resource: R,
    playerId: string,
    snapshots: Partial<Resources>,
  ): Promise<void> {
    const provider = this.providers[resource];

    if (!provider) {
      throw new WsException(`Resource unavailable: ${resource}`);
    }

    const snapshot = await provider(playerId);

    if (snapshot === undefined) {
      throw new Error(`Missing snapshot: ${resource}`);
    }

    snapshots[resource] = snapshot;
  }

  private getConnection(client: WebSocket): Connection {
    const connection = this.connections.get(client);

    if (!connection || client.readyState !== WebSocket.OPEN) {
      throw new WsException('Connection is closed');
    }

    return connection;
  }

  private getAuthenticatedConnection(client: WebSocket): Connection {
    const connection = this.getConnection(client);

    if (!connection.identity) {
      throw new WsException('Please authenticate first');
    }

    if (connection.identity.expiresAt <= Date.now()) {
      throw new WsException('Authentication has expired');
    }

    return connection;
  }

  private send(client: WebSocket, message: ServerMessage): void {
    if (client.readyState !== WebSocket.OPEN) return;

    const text = JSON.stringify(message);

    try {
      client.send(text, (error) => {
        if (error) {
          this.unregisterConnection(client);
          client.terminate();
        }
      });
    } catch {
      this.unregisterConnection(client);
      client.terminate();
    }
  }
}
