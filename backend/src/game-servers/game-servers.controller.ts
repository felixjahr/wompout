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
import { EndGameRequestDto } from './dto/end-game-request.dto';
import { GameServersGuard } from './game-servers.guard';

@Controller('game-servers')
export class GameServersController {
  constructor(private readonly gameServersService: GameServersService) {}

  @Post(':gameId/ready')
  @UseGuards(GameServersGuard)
  @HttpCode(HttpStatus.NO_CONTENT)
  markGameReady(@Param('gameId') gameId: string): void {
    this.gameServersService.markGameReady(gameId);
  }

  @Post(':gameId/end')
  @UseGuards(GameServersGuard)
  @HttpCode(HttpStatus.NO_CONTENT)
  endGameSession(
    @Param('gameId') gameId: string,
    @Body() request: EndGameRequestDto,
  ): Promise<void> {
    return this.gameServersService.endGame(gameId, request);
  }
}
