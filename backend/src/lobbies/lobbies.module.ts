import { Module } from '@nestjs/common';
import { LobbiesService } from './lobbies.service';
import { LobbiesController } from './lobbies.controller';
import { RealtimeModule } from '../realtime/realtime.module';
import { PrismaModule } from '../prisma/prisma.module';
import { MatchmakingModule } from '../matchmaking/matchmaking.module';
import { AuthModule } from '../auth/auth.module';
import { GameServersModule } from '../game-servers/game-servers.module';

@Module({
  imports: [
    PrismaModule,
    RealtimeModule,
    MatchmakingModule,
    AuthModule,
    GameServersModule,
  ],
  controllers: [LobbiesController],
  providers: [LobbiesService],
  exports: [LobbiesService],
})
export class LobbiesModule {}
