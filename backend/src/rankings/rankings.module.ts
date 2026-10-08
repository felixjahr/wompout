import { Module } from '@nestjs/common';

import { PrismaModule } from '../prisma/prisma.module';
import { PlayersModule } from '../players/players.module';
import { RealtimeModule } from '../realtime/realtime.module';
import { RankingsService } from './rankings.service';

@Module({
  imports: [PrismaModule, PlayersModule, RealtimeModule],
  providers: [RankingsService],
})
export class RankingsModule {}
