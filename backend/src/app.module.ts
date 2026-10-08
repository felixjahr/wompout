import { Module } from '@nestjs/common';
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
import { ShopModule } from './shop/shop.module';
import { RankingsModule } from './rankings/rankings.module';
import { MatchesModule } from './matches/matches.module';
import { SessionsModule } from './sessions/sessions.module';

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
    ShopModule,
    RankingsModule,
    MatchesModule,
    SessionsModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
