import {
  Controller,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  UseGuards,
} from '@nestjs/common';

import { SessionsGuard } from '../sessions/sessions.guard';
import { PlayerId } from '../sessions/decorators/player-id.decorator';
import { MatchesService } from './matches.service';

@Controller('matches')
@UseGuards(SessionsGuard)
export class MatchesController {
  constructor(private readonly matchesService: MatchesService) {}

  @Post(':gameId/acknowledge')
  @HttpCode(HttpStatus.NO_CONTENT)
  acknowledgeMatch(
    @PlayerId() playerId: string,
    @Param('gameId', ParseUUIDPipe) gameId: string,
  ): void {
    this.matchesService.acknowledgeMatch(playerId, gameId);
  }
}
