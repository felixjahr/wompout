import { Injectable } from '@nestjs/common';
import { Subject } from 'rxjs';
import { WebSocket } from 'ws';
import { RealtimeGatewayEvents } from './realtime.types';

@Injectable()
export class RealtimeService {
  private readonly socketByPlayerId = new Map<string, WebSocket>();
  private readonly playerIdBySocket = new Map<WebSocket, string>();

  private readonly connectedSubject = new Subject<string>();
  private readonly disconnectedSubject = new Subject<string>();

  readonly connected$ = this.connectedSubject.asObservable();
  readonly disconnected$ = this.disconnectedSubject.asObservable();

  registerPlayer(playerId: string, socket: WebSocket): void {
    const previousSocket = this.socketByPlayerId.get(playerId);

    if (previousSocket && previousSocket !== socket) {
      this.playerIdBySocket.delete(previousSocket);
      previousSocket.close();
    }

    this.socketByPlayerId.set(playerId, socket);
    this.playerIdBySocket.set(socket, playerId);
  }

  notifyPlayerConnected(playerId: string): void {
    this.connectedSubject.next(playerId);
  }

  unregisterSocket(socket: WebSocket): void {
    const playerId = this.playerIdBySocket.get(socket);
    if (!playerId) return;

    this.playerIdBySocket.delete(socket);

    if (this.socketByPlayerId.get(playerId) !== socket) {
      return;
    }

    this.socketByPlayerId.delete(playerId);
    this.disconnectedSubject.next(playerId);
  }

  sendToPlayer<EventName extends keyof RealtimeGatewayEvents>(
    playerId: string,
    event: EventName,
    data: RealtimeGatewayEvents[EventName],
  ): boolean {
    const socket = this.socketByPlayerId.get(playerId);
    if (!socket || socket.readyState !== WebSocket.OPEN) return false;

    socket.send(JSON.stringify({ event, data }));
    return true;
  }

  isPlayerConnected(playerId: string): boolean {
    return this.socketByPlayerId.get(playerId)?.readyState === WebSocket.OPEN;
  }
}
