import { UseFilters, UsePipes, ValidationPipe } from '@nestjs/common';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WsException,
} from '@nestjs/websockets';
import { WebSocket } from 'ws';

import { AuthenticateDto } from './dto/authenticate.dto';
import { SubscriptionDto } from './dto/subscription.dto';
import { RealtimeService } from './realtime.service';
import { RealtimeFilter } from './realtime.filter';

@WebSocketGateway({
  path: '/ws',
  maxPayload: 16 * 1024,
})
@UseFilters(new RealtimeFilter())
@UsePipes(
  new ValidationPipe({
    transform: true,
    whitelist: true,
    forbidNonWhitelisted: true,
    exceptionFactory: () => new WsException('Invalid request'),
  }),
)
export class RealtimeGateway
  implements OnGatewayConnection<WebSocket>, OnGatewayDisconnect<WebSocket>
{
  constructor(private readonly realtimeService: RealtimeService) {}

  handleConnection(client: WebSocket): void {
    this.realtimeService.registerConnection(client);
  }

  handleDisconnect(client: WebSocket): void {
    this.realtimeService.unregisterConnection(client);
  }

  @SubscribeMessage('authenticate')
  authenticate(
    @ConnectedSocket() client: WebSocket,
    @MessageBody() payload: AuthenticateDto,
  ): Promise<void> {
    return this.realtimeService.enqueue(client, () =>
      this.realtimeService.authenticate(client, payload.accessToken),
    );
  }

  @SubscribeMessage('subscribe')
  subscribe(
    @ConnectedSocket() client: WebSocket,
    @MessageBody() payload: SubscriptionDto,
  ): Promise<void> {
    return this.realtimeService.enqueue(client, () =>
      this.realtimeService.subscribe(client, payload.resources),
    );
  }

  @SubscribeMessage('unsubscribe')
  unsubscribe(
    @ConnectedSocket() client: WebSocket,
    @MessageBody() payload: SubscriptionDto,
  ): Promise<void> {
    return this.realtimeService.enqueue(client, () =>
      this.realtimeService.unsubscribe(client, payload.resources),
    );
  }
}
