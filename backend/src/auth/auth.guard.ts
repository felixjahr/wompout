import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
<<<<<<< HEAD
import { Request } from 'express';
import { AuthService } from './auth.service';

export type AuthenticatedRequest = Request & {
  auth?: {
    playerId: string;
    sessionId: string;
  };
};

@Injectable()
export class AuthGuard implements CanActivate {
  constructor(private readonly authService: AuthService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const token = this.extractBearerToken(request);

    if (!token) {
      throw new UnauthorizedException('Missing access token');
    }

    const auth = await this.authService.verifyAccessToken(token);

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
=======
import { AuthService } from './auth.service';

@Injectable()
export class AuthGuard implements CanActivate {
  constructor(private auth: AuthService) {}

  async canActivate(context: ExecutionContext) {
    const req = context.switchToHttp().getRequest();

    const header = req.headers.authorization;

    if (!header || !header.startsWith('Bearer ')) {
      throw new UnauthorizedException('Missing access token');
    }

    const accessToken = header.slice('Bearer '.length);
    const payload = await this.auth.verifyAccessToken(accessToken);

    req.playerId = payload.sub;
    req.sessionId = payload.sid;

    return true;
  }
>>>>>>> origin/main
}
