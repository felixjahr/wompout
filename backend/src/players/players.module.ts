import { Module } from '@nestjs/common';
import { PlayersService } from './players.service';
import { PrismaModule } from '../prisma/prisma.module';
import { RealtimeModule } from '../realtime/realtime.module';

@Module({
  imports: [PrismaModule, RealtimeModule],
  providers: [PlayersService],
  exports: [PlayersService],
})
export class PlayersModule {}
