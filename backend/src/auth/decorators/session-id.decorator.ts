import {
  createParamDecorator,
  ExecutionContext,
  UnauthorizedException,
} from '@nestjs/common';
import { AuthenticatedRequest } from '../auth.guard';

export const SessionId = createParamDecorator(
  (_data: unknown, context: ExecutionContext): string => {
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();

    const sessionId = request.auth?.sessionId;

    if (!sessionId) {
      throw new UnauthorizedException();
    }

    return sessionId;
  },
);
