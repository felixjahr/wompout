import { Module } from '@nestjs/common';
import { GameServersService } from './game-servers.service';
import { GameServersController } from './game-servers.controller';
import { PlayersModule } from '../players/players.module';
import { MatchesModule } from '../matches/matches.module';

@Module({
  imports: [PlayersModule, MatchesModule],
  controllers: [GameServersController],
  providers: [GameServersService],
  exports: [GameServersService],
})
export class GameServersModule {}
