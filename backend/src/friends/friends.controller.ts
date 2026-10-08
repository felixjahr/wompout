import {
  Controller,
  Get,
  Header,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Req,
  Res,
  UseGuards,
} from '@nestjs/common';
import { FriendsService } from './friends.service';
import { SessionsGuard } from '../sessions/sessions.guard';
import { PlayerId } from '../sessions/decorators/player-id.decorator';
import { CreateFriendInviteResponseDto } from './dto/create-friend-invite-response.dto';
import type { Request, Response } from 'express';

@Controller('friends')
export class FriendsController {
  constructor(private readonly friendsService: FriendsService) {}

  @Post('invite')
  @UseGuards(SessionsGuard)
  createInvite(
    @PlayerId() playerId: string,
  ): Promise<CreateFriendInviteResponseDto> {
    return this.friendsService.createInvite(playerId);
  }

  @Post('invite/:token/redeem')
  @UseGuards(SessionsGuard)
  @HttpCode(HttpStatus.NO_CONTENT)
  redeemInvite(
    @PlayerId() playerId: string,
    @Param('token') token: string,
  ): Promise<void> {
    return this.friendsService.redeemInvite(playerId, token);
  }

  @Get('invite/:token')
  @Header('Cache-Control', 'no-store')
  openInvite(
    @Param('token') token: string,
    @Req() request: Request,
    @Res() response: Response,
  ): Promise<void> {
    return this.friendsService.openInvite(token, request, response);
  }
}
