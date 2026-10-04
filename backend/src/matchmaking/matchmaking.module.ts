import { Module } from '@nestjs/common';
import { MatchmakingService } from './matchmaking.service';
import { GameServersModule } from '../game-servers/game-servers.module';

@Module({
  imports: [GameServersModule],
  providers: [MatchmakingService],
  exports: [MatchmakingService],
})
export class MatchmakingModule {}
