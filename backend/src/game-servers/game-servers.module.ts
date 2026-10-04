import { Module } from '@nestjs/common';
import { GameServersService } from './game-servers.service';
import { GameServersController } from './game-servers.controller';
import { PrismaModule } from '../prisma/prisma.module';
import { RealtimeModule } from '../realtime/realtime.module';
import { PlayersModule } from '../players/players.module';

@Module({
  imports: [PrismaModule, RealtimeModule, PlayersModule],
  controllers: [GameServersController],
  providers: [GameServersService],
  exports: [GameServersService],
})
export class GameServersModule {}
