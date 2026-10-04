import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import type { Request } from 'express';
import { GameServersService } from './game-servers.service';

@Injectable()
export class GameServersGuard implements CanActivate {
  constructor(private readonly gameServersService: GameServersService) {}

  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<Request>();
    const gameId = request.params.gameId;
    const callbackToken = this.extractBearerToken(request);

    if (typeof gameId !== 'string' || !callbackToken) {
      throw new UnauthorizedException('Invalid server callback secret');
    }

    if (!this.gameServersService.verifyCallbackToken(gameId, callbackToken)) {
      throw new UnauthorizedException('Invalid server callback secret');
    }

    return true;
  }

  private extractBearerToken(request: Request): string | undefined {
    const [type, token] = request.headers.authorization?.split(' ') ?? [];
    return type === 'Bearer' ? token : undefined;
  }
}
