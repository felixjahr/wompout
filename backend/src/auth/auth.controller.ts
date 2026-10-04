<<<<<<< HEAD
import {
  Body,
  Controller,
  HttpCode,
  HttpStatus,
  Post,
  UseGuards,
} from '@nestjs/common';
import { AuthService } from './auth.service';
import { CreateGuestRequestDto } from './dto/create-guest-request.dto';
import { TokenResponseDto } from './dto/token-response.dto';
import { EmailRequestDto } from './dto/email-request.dto';
import { VerifyEmailRequestDto } from './dto/verify-email-request.dto';
import { RefreshRequestDto } from './dto/refresh-request.dto';
import { PlayerId } from './decorators/player-id.decorator';
import { AuthGuard } from './auth.guard';
import { SessionId } from './decorators/session-id.decorator';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('guest')
  createGuest(
    @Body() request: CreateGuestRequestDto,
  ): Promise<TokenResponseDto> {
    return this.authService.createGuest(request);
  }

  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  refresh(@Body() request: RefreshRequestDto): Promise<TokenResponseDto> {
    return this.authService.refresh(request);
  }

  @Post('login/start')
  @HttpCode(HttpStatus.NO_CONTENT)
  startLogin(@Body() request: EmailRequestDto): Promise<void> {
    return this.authService.startLogin(request);
  }

  @Post('login/verify')
  @HttpCode(HttpStatus.OK)
  verifyLogin(
    @Body() request: VerifyEmailRequestDto,
  ): Promise<TokenResponseDto> {
    return this.authService.verifyLogin(request);
  }

  @Post('link/start')
  @UseGuards(AuthGuard)
  @HttpCode(HttpStatus.NO_CONTENT)
  startLink(
    @PlayerId() playerId: string,
    @Body() request: EmailRequestDto,
  ): Promise<void> {
    return this.authService.startLink(playerId, request);
  }

  @Post('link/verify')
  @UseGuards(AuthGuard)
  @HttpCode(HttpStatus.NO_CONTENT)
  verifyLink(
    @PlayerId() playerId: string,
    @Body() request: VerifyEmailRequestDto,
  ): Promise<void> {
    return this.authService.verifyLink(playerId, request);
  }

  @Post('logout')
  @UseGuards(AuthGuard)
  @HttpCode(HttpStatus.NO_CONTENT)
  logout(@SessionId() sessionId: string): Promise<void> {
    return this.authService.logout(sessionId);
=======
import { Body, Controller, Post } from '@nestjs/common';
import { AuthService } from './auth.service';

@Controller('auth')
export class AuthController {
  constructor(private auth: AuthService) {}

  @Post('guest')
  createGuest(@Body() body: { name?: string }) {
    return this.auth.createGuestAccount(body.name);
  }

  @Post('refresh')
  refresh(@Body() body: { refresh_token: string }) {
    return this.auth.refresh(body.refresh_token);
>>>>>>> origin/main
  }
}
