import { Module } from '@nestjs/common';
import { RoomsController } from './rooms.controller';
import { RoomsService } from './rooms.service';
import { RoomsGateway } from './rooms.gateway';
import { AuthModule } from '../auth/auth.module';
import { ServerCallbackGuard } from './server-callback.guard';
import { PrismaModule } from '../prisma.module';

@Module({
  imports: [AuthModule, PrismaModule],
  controllers: [RoomsController],
  providers: [RoomsService, RoomsGateway, ServerCallbackGuard],
})
export class RoomsModule {}
