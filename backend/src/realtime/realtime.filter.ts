import {
  ArgumentsHost,
  BadRequestException,
  Catch,
  Logger,
} from '@nestjs/common';
import type { ExceptionFilter } from '@nestjs/common';
import { WsException } from '@nestjs/websockets';
import { WebSocket } from 'ws';

import type { ServerMessage } from './realtime.types';

@Catch()
export class RealtimeFilter implements ExceptionFilter {
  private readonly logger = new Logger(RealtimeFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const context = host.switchToWs();
    const client = context.getClient<WebSocket>();
    const payload = context.getData<unknown>();

    let message = 'An unexpected error occurred';

    if (exception instanceof WsException) {
      const error = exception.getError();

      if (typeof error === 'string') {
        message = error;
      }
    } else if (exception instanceof BadRequestException) {
      message = 'Invalid request';
    } else {
      this.logger.error(
        'Unhandled realtime error',
        exception instanceof Error ? exception.stack : undefined,
      );
    }

    const response: ServerMessage = {
      event: 'error',
      data: {
        requestId: this.getRequestId(payload),
        message,
      },
    };

    if (client.readyState !== WebSocket.OPEN) return;

    try {
      const text = JSON.stringify(response);

      if (client.bufferedAmount + Buffer.byteLength(text) > 1_000_000) {
        client.terminate();
        return;
      }

      client.send(text, (error) => {
        if (error) client.terminate();
      });
    } catch {
      client.terminate();
    }
  }

  private getRequestId(payload: unknown): string | null {
    if (
      typeof payload !== 'object' ||
      payload === null ||
      !('requestId' in payload)
    ) {
      return null;
    }

    const requestId = payload.requestId;

    return typeof requestId === 'string' &&
      requestId.length > 0 &&
      requestId.length <= 100
      ? requestId
      : null;
  }
}
