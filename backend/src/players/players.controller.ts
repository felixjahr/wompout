import {
  Controller,
  HttpCode,
  HttpStatus,
  Post,
  UseGuards,
} from '@nestjs/common';
import { PlayersService } from './players.service';
import { SessionsGuard } from '../sessions/sessions.guard';
import { PlayerId } from '../sessions/decorators/player-id.decorator';
import type { ChestContent } from './players.types';

@Controller('players')
@UseGuards(SessionsGuard)
export class PlayersController {
  constructor(private readonly playersService: PlayersService) {}

  @Post('open')
  @HttpCode(HttpStatus.OK)
  openChest(@PlayerId() playerId: string): Promise<ChestContent> {
    return this.playersService.openChest(playerId);
  }
}
