import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

const DEV_SERVER_CALLBACK_SECRET = 'dev-server-secret';

@Injectable()
export class ServerCallbackGuard implements CanActivate {
  constructor(private readonly config: ConfigService) {}

  canActivate(context: ExecutionContext): boolean {
    const req = context.switchToHttp().getRequest();
    const expectedSecret =
      this.config.get<string>('SERVER_CALLBACK_SECRET') ??
      DEV_SERVER_CALLBACK_SECRET;
    const actualSecret = req.headers['x-server-secret'];

    if (actualSecret !== expectedSecret) {
      throw new UnauthorizedException('Invalid server callback secret');
    }

    return true;
  }
}
