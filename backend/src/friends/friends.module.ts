import { Module } from '@nestjs/common';
import { FriendsService } from './friends.service';
import { FriendsController } from './friends.controller';
import { PrismaModule } from '../prisma/prisma.module';
import { LobbiesModule } from '../lobbies/lobbies.module';
import { RealtimeModule } from '../realtime/realtime.module';
import { SessionsModule } from '../sessions/sessions.module';
import { PlayersModule } from '../players/players.module';

@Module({
  imports: [
    PrismaModule,
    SessionsModule,
    LobbiesModule,
    RealtimeModule,
    PlayersModule,
  ],
  controllers: [FriendsController],
  providers: [FriendsService],
})
export class FriendsModule {}
