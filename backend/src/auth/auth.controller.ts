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
import { TokenResponseDto } from '../sessions/dto/token-response.dto';
import { EmailRequestDto } from './dto/email-request.dto';
import { VerifyEmailRequestDto } from './dto/verify-email-request.dto';
import { SessionsGuard } from '../sessions/sessions.guard';
import { PlayerId } from '../sessions/decorators/player-id.decorator';
import { StartSignupRequestDto } from './dto/start-signup-request.dto';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('guest')
  createGuest(
    @Body() request: CreateGuestRequestDto,
  ): Promise<TokenResponseDto> {
    return this.authService.createGuest(request);
  }

  @Post('signup/start')
  @HttpCode(HttpStatus.NO_CONTENT)
  startSignup(@Body() request: StartSignupRequestDto): Promise<void> {
    return this.authService.startSignup(request);
  }

  @Post('signup/verify')
  @HttpCode(HttpStatus.OK)
  verifySignup(
    @Body() request: VerifyEmailRequestDto,
  ): Promise<TokenResponseDto> {
    return this.authService.verifySignup(request);
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
  @UseGuards(SessionsGuard)
  @HttpCode(HttpStatus.NO_CONTENT)
  startLink(
    @PlayerId() playerId: string,
    @Body() request: EmailRequestDto,
  ): Promise<void> {
    return this.authService.startLink(playerId, request);
  }

  @Post('link/verify')
  @UseGuards(SessionsGuard)
  @HttpCode(HttpStatus.NO_CONTENT)
  verifyLink(
    @PlayerId() playerId: string,
    @Body() request: VerifyEmailRequestDto,
  ): Promise<void> {
    return this.authService.verifyLink(playerId, request);
  }
}
