import {
  OnGatewayConnection,
  OnGatewayDisconnect,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import type { Server, WebSocket } from 'ws';
import { AuthService } from '../auth/auth.service';

@WebSocketGateway({
  path: '/ws',
})
export class RoomsGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  private readonly playerSockets = new Map<string, WebSocket>();
  private readonly socketPlayers = new Map<WebSocket, string>();
  private readonly disconnectListeners: Array<(playerId: string) => void> = [];

  constructor(private readonly authService: AuthService) {}

  handleConnection(client: WebSocket): void {
    client.on('message', async (raw) => {
      try {
        const text = raw.toString();
        const msg = JSON.parse(text);

        if (msg?.event !== 'auth') {
          return;
        }

        const accessToken = msg?.data?.accessToken;
        if (!accessToken) {
          this.sendAuthFailed(client);
          return;
        }

        const payload = await this.authService.verifyAccessToken(accessToken);
        const playerId = payload.sub;
        const previousSocket = this.playerSockets.get(playerId);
        if (previousSocket && previousSocket !== client) {
          this.socketPlayers.delete(previousSocket);
          previousSocket.close();
        }

        this.playerSockets.set(playerId, client);
        this.socketPlayers.set(client, playerId);

        client.send(
          JSON.stringify({
            event: 'authOk',
            data: {
              playerId,
            },
          }),
        );
      } catch {
        this.sendAuthFailed(client);
      }
    });
  }

  handleDisconnect(client: WebSocket): void {
    const playerId = this.socketPlayers.get(client);
    if (!playerId) return;

    this.socketPlayers.delete(client);
    if (this.playerSockets.get(playerId) === client) {
      this.playerSockets.delete(playerId);
    }
    for (const listener of this.disconnectListeners) {
      listener(playerId);
    }
  }

  onPlayerDisconnected(listener: (playerId: string) => void): void {
    this.disconnectListeners.push(listener);
  }

  hasPlayer(playerId: string): boolean {
    const socket = this.playerSockets.get(playerId);
    return !!socket && socket.readyState === socket.OPEN;
  }

  sendRoomStart(
    playerId: string,
    ip: string,
    port: number,
    gameToken: string,
    playerNames: Record<string, string>,
  ): boolean {
    const socket = this.playerSockets.get(playerId);
    if (!socket || socket.readyState !== socket.OPEN) return false;

    socket.send(
      JSON.stringify({
        event: 'receiveRoomStart',
        data: { ip, port, gameToken, playerNames },
      }),
    );
    return true;
  }

  sendRoomFailed(playerId: string): void {
    const socket = this.playerSockets.get(playerId);
    if (!socket || socket.readyState !== socket.OPEN) return;

    socket.send(
      JSON.stringify({
        event: 'roomFailed',
        data: {},
      }),
    );
  }

  private sendAuthFailed(client: WebSocket): void {
    if (client.readyState !== client.OPEN) return;
    client.send(
      JSON.stringify({
        event: 'authFailed',
        data: {},
      }),
    );
  }
}
