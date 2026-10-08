import {
  Body,
  Controller,
  HttpCode,
  HttpStatus,
  Post,
  UseGuards,
} from '@nestjs/common';
import { SessionsService } from './sessions.service';
import { TokenResponseDto } from './dto/token-response.dto';
import { RefreshRequestDto } from './dto/refresh-request.dto';
import { SessionsGuard } from './sessions.guard';
import { SessionId } from './decorators/session-id.decorator';

@Controller('sessions')
export class SessionsController {
  constructor(private readonly sessionsService: SessionsService) {}

  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  refresh(@Body() request: RefreshRequestDto): Promise<TokenResponseDto> {
    return this.sessionsService.refresh(request);
  }

  @Post('logout')
  @UseGuards(SessionsGuard)
  @HttpCode(HttpStatus.NO_CONTENT)
  logout(@SessionId() sessionId: string): Promise<void> {
    return this.sessionsService.logout(sessionId);
  }
}
