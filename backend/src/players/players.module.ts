import { Module } from '@nestjs/common';
import { PlayersService } from './players.service';
import { PrismaModule } from '../prisma/prisma.module';
import { RealtimeModule } from '../realtime/realtime.module';
import { AuthModule } from '../auth/auth.module';

@Module({
  imports: [PrismaModule, RealtimeModule, AuthModule],
  providers: [PlayersService],
  exports: [PlayersService],
})
export class PlayersModule {}
