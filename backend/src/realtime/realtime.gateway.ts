import {
  ConnectedSocket,
  MessageBody,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
} from '@nestjs/websockets';
import { WebSocket } from 'ws';
import { AuthService } from '../auth/auth.service';
import { RealtimeService } from './realtime.service';

type AuthPayload = {
  accessToken?: string;
};

@WebSocketGateway({ path: '/ws' })
export class RealtimeGateway implements OnGatewayDisconnect<WebSocket> {
  constructor(
    private readonly authService: AuthService,
    private readonly realtimeService: RealtimeService,
  ) {}

  handleDisconnect(client: WebSocket): void {
    this.realtimeService.unregisterSocket(client);
  }

  @SubscribeMessage('auth')
  async handleAuth(
    @ConnectedSocket() client: WebSocket,
    @MessageBody() payload: AuthPayload,
  ): Promise<void> {
    const accessToken = payload?.accessToken;

    if (!accessToken) {
      this.sendAuthFailed(client);
      return;
    }

    try {
      const auth = await this.authService.verifyAccessToken(accessToken);

      this.realtimeService.registerPlayer(auth.playerId, client);

      this.sendAuthOk(client);

      this.realtimeService.notifyPlayerConnected(auth.playerId);
    } catch {
      this.sendAuthFailed(client);
    }
  }

  private sendAuthOk(client: WebSocket): void {
    client.send(
      JSON.stringify({
        event: 'authOk',
        data: {},
      }),
    );
  }

  private sendAuthFailed(client: WebSocket): void {
    client.send(
      JSON.stringify({
        event: 'authFailed',
        data: {},
      }),
    );
  }
}
