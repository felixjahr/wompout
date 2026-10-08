import {
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { CreateGuestRequestDto } from './dto/create-guest-request.dto';
import { TokenResponseDto } from '../sessions/dto/token-response.dto';
import { PrismaService } from '../prisma/prisma.service';
import { createHmac, randomInt, timingSafeEqual } from 'node:crypto';
import { ConfigService } from '@nestjs/config';
import { EmailRequestDto } from './dto/email-request.dto';
import { EmailService } from '../email/email.service';
import { VerifyEmailRequestDto } from './dto/verify-email-request.dto';
import {
  DEFAULT_ITEMS,
  DEFAULT_LOADOUT,
} from '../config/default-player.config';
import { SessionsService } from '../sessions/sessions.service';
import { PlayersService } from '../players/players.service';
import { StartSignupRequestDto } from './dto/start-signup-request.dto';
import { Prisma } from '../../generated/prisma/client';

@Injectable()
export class AuthService {
  constructor(
    private readonly configService: ConfigService,
    private readonly prismaService: PrismaService,
    private readonly sessionsService: SessionsService,
    private readonly emailService: EmailService,
    private readonly playersService: PlayersService,
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

    return this.sessionsService.createSession(player.id);
  }

  async startSignup(request: StartSignupRequestDto): Promise<void> {
    const existingPlayer = await this.prismaService.player.findUnique({
      where: { email: request.email },
      select: { id: true },
    });

    if (existingPlayer) {
      throw new ConflictException('Email is already registered');
    }

    const code = this.createEmailVerificationCode();
    const expirationMs = Number(
      this.configService.getOrThrow<string>(
        'EMAIL_VERIFICATION_CODE_EXPIRATION_MS',
      ),
    );

    await this.prismaService.signupVerificationCode.create({
      data: {
        displayName: request.displayName,
        email: request.email,
        codeHash: this.hashEmailVerificationCode(code),
        expiresAt: new Date(Date.now() + expirationMs),
      },
    });

    await this.emailService.sendEmailVerificationCode(request.email, code);
  }

  async verifySignup(
    request: VerifyEmailRequestDto,
  ): Promise<TokenResponseDto> {
    const verification =
      await this.prismaService.signupVerificationCode.findFirst({
        where: { email: request.email },
        orderBy: { createdAt: 'desc' },
      });

    if (
      !verification ||
      verification.usedAt ||
      verification.expiresAt <= new Date() ||
      !this.verifyEmailVerificationCode(request.code, verification.codeHash)
    ) {
      throw new UnauthorizedException('Invalid or expired verification code');
    }

    const player = await this.prismaService
      .$transaction(async (tx) => {
        const consumed = await tx.signupVerificationCode.updateMany({
          where: {
            id: verification.id,
            usedAt: null,
            expiresAt: { gt: new Date() },
          },
          data: { usedAt: new Date() },
        });

        if (consumed.count !== 1) {
          throw new UnauthorizedException(
            'Invalid or expired verification code',
          );
        }

        return tx.player.create({
          data: {
            displayName: verification.displayName,
            email: verification.email,
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
      })
      .catch((error: unknown) => {
        if (
          error instanceof Prisma.PrismaClientKnownRequestError &&
          error.code === 'P2002'
        ) {
          throw new ConflictException('Email is already registered');
        }

        throw error;
      });

    return this.sessionsService.createSession(player.id);
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

    return this.sessionsService.createSession(emailVerificationCode.playerId);
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

    await this.playersService.updateEmail(
      playerId,
      emailVerificationCode.email,
    );
  }

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
}
