import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { Request } from 'express';
import { SessionsService } from './sessions.service';

export type AuthenticatedRequest = Request & {
  auth?: {
    playerId: string;
    sessionId: string;
  };
};

@Injectable()
export class SessionsGuard implements CanActivate {
  constructor(private readonly sessionsService: SessionsService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const token = this.extractBearerToken(request);

    if (!token) {
      throw new UnauthorizedException('Missing access token');
    }

    const auth = await this.sessionsService.verifyAccessToken(token);

    request.auth = {
      playerId: auth.playerId,
      sessionId: auth.sessionId,
    };

    return true;
  }

  private extractBearerToken(request: Request): string | undefined {
    const [type, token] = request.headers.authorization?.split(' ') ?? [];
    return type === 'Bearer' ? token : undefined;
  }
}
