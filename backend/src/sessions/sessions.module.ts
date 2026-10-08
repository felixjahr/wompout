import { Module } from '@nestjs/common';
import { SessionsService } from './sessions.service';
import { PrismaModule } from '../prisma/prisma.module';
import { JwtModule } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { SessionsController } from './sessions.controller';
import { SessionsGuard } from './sessions.guard';

@Module({
  imports: [
    PrismaModule,
    JwtModule.registerAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.getOrThrow<string>('JWT_SECRET'),
        signOptions: {
          expiresIn:
            Number(config.getOrThrow<string>('JWT_EXPIRATION_MS')) / 1000,
        },
      }),
    }),
  ],
  controllers: [SessionsController],
  providers: [SessionsService, SessionsGuard],
  exports: [SessionsService, SessionsGuard],
})
export class SessionsModule {}
