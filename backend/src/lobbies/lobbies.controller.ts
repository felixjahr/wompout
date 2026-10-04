import {
  Body,
  Controller,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import { LobbiesService } from './lobbies.service';
import { AuthGuard } from '../auth/auth.guard';
import { PlayerId } from '../auth/decorators/player-id.decorator';
import { InvitePlayerRequestDto } from './dto/invite-player-request.dto';
import { UpdateModeRequestDto } from './dto/update-mode-request.dto';
import { UpdateReadyRequestDto } from './dto/update-ready-request.dto';

@Controller('lobbies')
@UseGuards(AuthGuard)
export class LobbiesController {
  constructor(private readonly lobbiesService: LobbiesService) {}

  @Post('invite')
  @HttpCode(HttpStatus.NO_CONTENT)
  invitePlayer(
    @PlayerId() playerId: string,
    @Body() request: InvitePlayerRequestDto,
  ): void {
    this.lobbiesService.invitePlayer(playerId, request);
  }

  @Post('invites/:inviteId/accept')
  @HttpCode(HttpStatus.NO_CONTENT)
  acceptInvite(
    @PlayerId() playerId: string,
    @Param('inviteId') inviteId: string,
  ): Promise<void> {
    return this.lobbiesService.acceptInvite(playerId, inviteId);
  }

  @Post('invites/:inviteId/decline')
  @HttpCode(HttpStatus.NO_CONTENT)
  declineInvite(
    @PlayerId() playerId: string,
    @Param('inviteId') inviteId: string,
  ): void {
    this.lobbiesService.declineInvite(playerId, inviteId);
  }

  @Post('leave')
  @HttpCode(HttpStatus.NO_CONTENT)
  leaveLobby(@PlayerId() playerId: string): Promise<void> {
    return this.lobbiesService.leaveLobby(playerId);
  }

  @Post('mode')
  @HttpCode(HttpStatus.NO_CONTENT)
  updateMode(
    @PlayerId() playerId: string,
    @Body() request: UpdateModeRequestDto,
  ): void {
    this.lobbiesService.updateMode(playerId, request);
  }

  @Post('ready')
  @HttpCode(HttpStatus.NO_CONTENT)
  updateReady(
    @PlayerId() playerId: string,
    @Body() request: UpdateReadyRequestDto,
  ): void {
    this.lobbiesService.updateReady(playerId, request);
  }
}
