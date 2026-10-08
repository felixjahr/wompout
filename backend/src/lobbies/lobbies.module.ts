import { Module } from '@nestjs/common';
import { LobbiesService } from './lobbies.service';
import { LobbiesController } from './lobbies.controller';
import { RealtimeModule } from '../realtime/realtime.module';
import { MatchmakingModule } from '../matchmaking/matchmaking.module';
import { GameServersModule } from '../game-servers/game-servers.module';
import { SessionsModule } from '../sessions/sessions.module';
import { PlayersModule } from '../players/players.module';

@Module({
  imports: [
    PlayersModule,
    RealtimeModule,
    MatchmakingModule,
    SessionsModule,
    GameServersModule,
  ],
  controllers: [LobbiesController],
  providers: [LobbiesService],
  exports: [LobbiesService],
})
export class LobbiesModule {}
