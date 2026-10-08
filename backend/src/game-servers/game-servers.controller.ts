import {
  Body,
  Controller,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import { GameServersService } from './game-servers.service';
import { GameResultsDto } from './dto/game-results.dto';
import { GameServersGuard } from './game-servers.guard';

@Controller('game-servers')
@UseGuards(GameServersGuard)
export class GameServersController {
  constructor(private readonly gameServersService: GameServersService) {}

  @Post(':gameId/ready')
  @HttpCode(HttpStatus.NO_CONTENT)
  markGameReady(@Param('gameId') gameId: string): void {
    this.gameServersService.markGameReady(gameId);
  }

  @Post(':gameId/results')
  @HttpCode(HttpStatus.NO_CONTENT)
  reportResults(
    @Param('gameId') gameId: string,
    @Body() request: GameResultsDto,
  ): Promise<void> {
    return this.gameServersService.reportResults(gameId, request);
  }

  @Post(':gameId/end')
  @HttpCode(HttpStatus.NO_CONTENT)
  endGameSession(@Param('gameId') gameId: string): Promise<void> {
    return this.gameServersService.endGame(gameId);
  }
}
