import { Module } from '@nestjs/common';
<<<<<<< HEAD
import { AuthModule } from './auth/auth.module';
import { PrismaModule } from './prisma/prisma.module';
import { ConfigModule } from '@nestjs/config';
import { EmailModule } from './email/email.module';
import { GameServersModule } from './game-servers/game-servers.module';
import { RealtimeModule } from './realtime/realtime.module';
import { LobbiesModule } from './lobbies/lobbies.module';
import { FriendsModule } from './friends/friends.module';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { MatchmakingModule } from './matchmaking/matchmaking.module';
import { PlayersModule } from './players/players.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
    }),
    AuthModule,
    PrismaModule,
    EmailModule,
    GameServersModule,
    RealtimeModule,
    LobbiesModule,
    FriendsModule,
    MatchmakingModule,
    PlayersModule,
  ],
=======
import { ConfigModule } from '@nestjs/config';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { RoomsModule } from './rooms/rooms.module';
import { AuthModule } from './auth/auth.module';

@Module({
  imports: [ConfigModule.forRoot({ isGlobal: true }), RoomsModule, AuthModule],
>>>>>>> origin/main
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
