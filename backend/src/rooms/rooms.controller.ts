import { Controller, HttpCode, Param, Post, Req, UseGuards } from '@nestjs/common';
import { RoomsService } from './rooms.service';
import { AuthGuard } from '../auth/auth.guard';
import { ServerCallbackGuard } from './server-callback.guard';

type AuthenticatedRequest = Request & {
  playerId: string;
  sessionId: string;
};

@Controller('rooms')
export class RoomsController {
  constructor(private readonly roomsService: RoomsService) {}

  @Post('create')
  @UseGuards(AuthGuard)
  createRoom(@Req() req: AuthenticatedRequest) {
    return this.roomsService.createRoom(req.playerId);
  }

  @Post('join/:code')
  @HttpCode(204)
  @UseGuards(AuthGuard)
  joinRoom(@Param('code') code: string, @Req() req: AuthenticatedRequest) {
    this.roomsService.joinRoom(code, req.playerId);
  }

  @Post('leave/:code')
  @HttpCode(204)
  @UseGuards(AuthGuard)
  leaveRoom(@Param('code') code: string, @Req() req: AuthenticatedRequest) {
    this.roomsService.leaveRoom(code, req.playerId);
  }

  @Post('start/:code')
  @HttpCode(204)
  @UseGuards(ServerCallbackGuard)
  startRoom(@Param('code') code: string) {
    this.roomsService.startRoom(code);
  }

  @Post('end/:code')
  @HttpCode(204)
  @UseGuards(ServerCallbackGuard)
  endRoom(@Param('code') code: string) {
    this.roomsService.endRoom(code);
  }
}
