import { Module } from '@nestjs/common';
import { ShopService } from './shop.service';
import { ShopController } from './shop.controller';
import { RealtimeModule } from '../realtime/realtime.module';
import { PlayersModule } from '../players/players.module';
import { SessionsModule } from '../sessions/sessions.module';

@Module({
  imports: [RealtimeModule, PlayersModule, SessionsModule],
  controllers: [ShopController],
  providers: [ShopService],
})
export class ShopModule {}
