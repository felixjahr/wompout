<<<<<<< HEAD
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { CreateGuestRequestDto } from './dto/create-guest-request.dto';
import { TokenResponseDto } from './dto/token-response.dto';
import { PrismaService } from '../prisma/prisma.service';
import {
  createHash,
  createHmac,
  randomBytes,
  randomInt,
  timingSafeEqual,
} from 'node:crypto';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { RefreshRequestDto } from './dto/refresh-request.dto';
import { EmailRequestDto } from './dto/email-request.dto';
import { EmailService } from '../email/email.service';
import { VerifyEmailRequestDto } from './dto/verify-email-request.dto';
import {
  DEFAULT_ITEMS,
  DEFAULT_LOADOUT,
} from '../config/default-player.config';
import { Subject } from 'rxjs';

@Injectable()
export class AuthService {
  private readonly playerChangedSubject = new Subject<string>();
  readonly playerChanged$ = this.playerChangedSubject.asObservable();

  constructor(
    private readonly configService: ConfigService,
    private readonly prismaService: PrismaService,
    private readonly jwtService: JwtService,
    private readonly emailService: EmailService,
  ) {}

  async createGuest(request: CreateGuestRequestDto): Promise<TokenResponseDto> {
    const player = await this.prismaService.player.create({
      data: {
        displayName: request.displayName,
        progression: {
          create: {
            trophies: 0,
            highestTrophies: 0,
          },
        },
        loadout: {
          create: DEFAULT_LOADOUT,
        },
        items: {
          create: DEFAULT_ITEMS.map((item) => ({
            itemType: item.itemType,
            itemId: item.itemId,
          })),
        },
      },
    });

    return this.createSession(player.id);
  }

  async refresh(request: RefreshRequestDto): Promise<TokenResponseDto> {
    const refreshTokenHash = this.hashRefreshToken(request.refreshToken);

    const session = await this.prismaService.session.findUnique({
      where: {
        refreshTokenHash,
      },
    });

    if (!session || session.revokedAt || session.expiresAt <= new Date()) {
      throw new UnauthorizedException('Invalid refresh token');
    }

    const newRefreshToken = this.createRefreshToken();

    await this.prismaService.session.update({
      where: {
        id: session.id,
      },
      data: {
        refreshTokenHash: this.hashRefreshToken(newRefreshToken),
        expiresAt: new Date(
          Date.now() +
            Number(
              this.configService.getOrThrow<string>(
                'REFRESH_TOKEN_EXPIRATION_MS',
              ),
            ),
        ),
      },
    });

    const newAccessToken = await this.createAccessToken(
      session.playerId,
      session.id,
    );

    return {
      access_token: newAccessToken,
      refresh_token: newRefreshToken,
    };
  }

  async startLogin(request: EmailRequestDto): Promise<void> {
    const player = await this.prismaService.player.findUnique({
      where: {
        email: request.email,
      },
    });

    if (!player) {
      return;
    }

    const code = this.createEmailVerificationCode();

    await this.prismaService.emailVerificationCode.create({
      data: {
        playerId: player.id,
        email: request.email,
        codeHash: this.hashEmailVerificationCode(code),
        expiresAt: new Date(
          Date.now() +
            Number(
              this.configService.getOrThrow<string>(
                'EMAIL_VERIFICATION_CODE_EXPIRATION_MS',
              ),
            ),
        ),
      },
    });

    await this.emailService.sendEmailVerificationCode(request.email, code);
  }

  async verifyLogin(request: VerifyEmailRequestDto): Promise<TokenResponseDto> {
    const emailVerificationCode =
      await this.prismaService.emailVerificationCode.findFirst({
        where: {
          email: request.email,
        },
        orderBy: {
          createdAt: 'desc',
        },
      });

    if (
      !emailVerificationCode ||
      emailVerificationCode.usedAt ||
      emailVerificationCode.expiresAt <= new Date()
    ) {
      throw new UnauthorizedException('Invalid or expired verification code');
    }

    if (
      !this.verifyEmailVerificationCode(
        request.code,
        emailVerificationCode.codeHash,
      )
    ) {
      throw new UnauthorizedException('Invalid or expired verification code');
    }

    await this.prismaService.emailVerificationCode.update({
      where: {
        id: emailVerificationCode.id,
      },
      data: {
        usedAt: new Date(),
      },
    });

    return this.createSession(emailVerificationCode.playerId);
  }

  async startLink(playerId: string, request: EmailRequestDto): Promise<void> {
    const existingPlayer = await this.prismaService.player.findUnique({
      where: {
        email: request.email,
      },
      select: {
        id: true,
      },
    });

    if (existingPlayer) {
      return;
    }

    const code = this.createEmailVerificationCode();

    await this.prismaService.emailVerificationCode.create({
      data: {
        playerId,
        email: request.email,
        codeHash: this.hashEmailVerificationCode(code),
        expiresAt: new Date(
          Date.now() +
            Number(
              this.configService.getOrThrow<string>(
                'EMAIL_VERIFICATION_CODE_EXPIRATION_MS',
              ),
            ),
        ),
      },
    });

    await this.emailService.sendEmailVerificationCode(request.email, code);
  }

  async verifyLink(
    playerId: string,
    request: VerifyEmailRequestDto,
  ): Promise<void> {
    const emailVerificationCode =
      await this.prismaService.emailVerificationCode.findFirst({
        where: {
          playerId,
          email: request.email,
        },
        orderBy: {
          createdAt: 'desc',
        },
      });

    if (
      !emailVerificationCode ||
      emailVerificationCode.usedAt ||
      emailVerificationCode.expiresAt <= new Date()
    ) {
      throw new UnauthorizedException('Invalid or expired verification code');
    }

    if (
      !this.verifyEmailVerificationCode(
        request.code,
        emailVerificationCode.codeHash,
      )
    ) {
      throw new UnauthorizedException('Invalid or expired verification code');
    }

    await this.prismaService.emailVerificationCode.update({
      where: {
        id: emailVerificationCode.id,
      },
      data: {
        usedAt: new Date(),
      },
    });

    await this.prismaService.player.update({
      where: {
        id: playerId,
      },
      data: {
        email: emailVerificationCode.email,
      },
    });

    this.playerChangedSubject.next(playerId);
  }

  async logout(sessionId: string): Promise<void> {
    await this.prismaService.session.updateMany({
      where: {
        id: sessionId,
        revokedAt: null,
      },
      data: {
        revokedAt: new Date(),
      },
    });
  }

  async verifyAccessToken(accessToken: string): Promise<{
    playerId: string;
    sessionId: string;
  }> {
    const payload: unknown = await this.jwtService.verifyAsync(accessToken);

    if (!this.isValidAccessTokenPayload(payload)) {
      throw new UnauthorizedException('Invalid access token');
    }

    return {
      playerId: payload.sub,
      sessionId: payload.sid,
    };
  }

=======
import {
  BadRequestException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../prisma.service';
import { ulid } from 'ulid';
import * as bcrypt from 'bcrypt';
import { randomBytes } from 'crypto';

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwt: JwtService,
  ) {}

>>>>>>> origin/main
  private createRefreshToken(): string {
    return randomBytes(64).toString('base64url');
  }

<<<<<<< HEAD
  private hashRefreshToken(refreshToken: string): string {
    return createHash('sha256').update(refreshToken).digest('hex');
  }

  private async createAccessToken(
    playerId: string,
    sessionId: string,
  ): Promise<string> {
    return this.jwtService.signAsync({
=======
  private async createAccessToken(playerId: string, sessionId: string) {
    return this.jwt.signAsync({
>>>>>>> origin/main
      sub: playerId,
      sid: sessionId,
    });
  }

<<<<<<< HEAD
  private createEmailVerificationCode(): string {
    return randomInt(100000, 1_000_000).toString();
  }

  private hashEmailVerificationCode(emailVerificationCode: string): string {
    const secret = this.configService.getOrThrow<string>(
      'EMAIL_VERIFICATION_CODE_SECRET',
    );
    return createHmac('sha256', secret)
      .update(emailVerificationCode)
      .digest('hex');
  }

  private verifyEmailVerificationCode(
    actualEmailVerificationCode: string,
    expectedEmailVerificationCodeHash: string,
  ): boolean {
    const actualEmailVerificationCodeHash = this.hashEmailVerificationCode(
      actualEmailVerificationCode,
    );

    const actual = Buffer.from(actualEmailVerificationCodeHash, 'hex');
    const expected = Buffer.from(expectedEmailVerificationCodeHash, 'hex');

    if (actual.length !== expected.length) {
      return false;
    }

    return timingSafeEqual(actual, expected);
  }

  private async createSession(playerId: string): Promise<TokenResponseDto> {
    const refreshToken = this.createRefreshToken();

    const session = await this.prismaService.session.create({
      data: {
        playerId,
        refreshTokenHash: this.hashRefreshToken(refreshToken),
        expiresAt: new Date(
          Date.now() +
            Number(
              this.configService.getOrThrow<string>(
                'REFRESH_TOKEN_EXPIRATION_MS',
              ),
            ),
        ),
      },
    });

    const accessToken = await this.createAccessToken(playerId, session.id);

    return {
      access_token: accessToken,
=======
  async createGuestAccount(name?: string) {
    const trimmedName = name?.trim();
    if (!trimmedName) {
      throw new BadRequestException('Name is required');
    }

    const playerId = ulid();
    const sessionId = ulid();
    const refreshToken = this.createRefreshToken();

    await this.prisma.player.create({
      data: {
        id: playerId,
        name: trimmedName,
        sessions: {
          create: {
            id: sessionId,
            refreshTokenHash: await bcrypt.hash(refreshToken, 12),
          },
        },
      },
    });

    return {
      player_id: playerId,
      player_name: trimmedName,
      access_token: await this.createAccessToken(playerId, sessionId),
>>>>>>> origin/main
      refresh_token: refreshToken,
    };
  }

<<<<<<< HEAD
  private isValidAccessTokenPayload(
    payload: unknown,
  ): payload is { sub: string; sid: string } {
    return (
      typeof payload === 'object' &&
      payload !== null &&
      'sub' in payload &&
      'sid' in payload &&
      typeof payload.sub === 'string' &&
      typeof payload.sid === 'string'
    );
=======
  async refresh(refreshToken: string) {
    const sessions = await this.prisma.session.findMany({
      include: {
        player: true,
      },
    });

    for (const session of sessions) {
      const matches = await bcrypt.compare(
        refreshToken,
        session.refreshTokenHash,
      );

      if (matches) {
        return {
          player_id: session.playerId,
          player_name: session.player.name,
          access_token: await this.createAccessToken(
            session.playerId,
            session.id,
          ),
          refresh_token: refreshToken,
        };
      }
    }

    throw new UnauthorizedException('Invalid refresh token');
  }

  async verifyAccessToken(accessToken: string) {
    try {
      return await this.jwt.verifyAsync(accessToken);
    } catch {
      throw new UnauthorizedException('Invalid access token');
    }
>>>>>>> origin/main
  }
}
