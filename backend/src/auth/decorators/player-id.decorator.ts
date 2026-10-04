import {
  createParamDecorator,
  ExecutionContext,
  UnauthorizedException,
} from '@nestjs/common';
import { AuthenticatedRequest } from '../auth.guard';

export const PlayerId = createParamDecorator(
  (_data: unknown, context: ExecutionContext): string => {
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();

    const playerId = request.auth?.playerId;

    if (!playerId) {
      throw new UnauthorizedException();
    }

    return playerId;
  },
);
