import { Module } from '@nestjs/common';
import { PlayersService } from './players.service';
import { PrismaModule } from '../prisma/prisma.module';
import { RealtimeModule } from '../realtime/realtime.module';
import { PlayersController } from './players.controller';
import { SessionsModule } from '../sessions/sessions.module';

@Module({
  imports: [PrismaModule, RealtimeModule, SessionsModule],
  providers: [PlayersService],
  exports: [PlayersService],
  controllers: [PlayersController],
})
export class PlayersModule {}
