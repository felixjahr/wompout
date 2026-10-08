import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { createHash, randomBytes } from 'node:crypto';
import { PrismaService } from '../prisma/prisma.service';
import { RefreshRequestDto } from './dto/refresh-request.dto';

export interface SessionTokens {
  access_token: string;
  refresh_token: string;
}

export interface VerifiedSession {
  playerId: string;
  sessionId: string;
  expiresAt: number;
}

interface AccessTokenPayload {
  sub: string;
  sid: string;
  exp: number;
}

@Injectable()
export class SessionsService {
  constructor(
    private readonly prismaService: PrismaService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  async createSession(playerId: string): Promise<SessionTokens> {
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
      refresh_token: refreshToken,
    };
  }

  async refresh(request: RefreshRequestDto): Promise<SessionTokens> {
    const refreshTokenHash = this.hashRefreshToken(request.refreshToken);

    const session = await this.prismaService.session.findUnique({
      where: { refreshTokenHash },
    });

    if (!session || session.revokedAt || session.expiresAt <= new Date()) {
      throw new UnauthorizedException('Invalid refresh token');
    }

    const newRefreshToken = this.createRefreshToken();

    const accessToken = await this.createAccessToken(
      session.playerId,
      session.id,
    );

    const updated = await this.prismaService.session.updateMany({
      where: {
        id: session.id,
        refreshTokenHash,
        revokedAt: null,
        expiresAt: { gt: new Date() },
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

    if (updated.count !== 1) {
      throw new UnauthorizedException('Invalid refresh token');
    }

    return {
      access_token: accessToken,
      refresh_token: newRefreshToken,
    };
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

  async verifyAccessToken(accessToken: string): Promise<VerifiedSession> {
    let payload: unknown;

    try {
      payload = await this.jwtService.verifyAsync(accessToken);
    } catch {
      throw new UnauthorizedException('Invalid or expired access token');
    }

    if (!this.isValidAccessTokenPayload(payload)) {
      throw new UnauthorizedException('Invalid access token');
    }

    return {
      playerId: payload.sub,
      sessionId: payload.sid,
      expiresAt: payload.exp * 1000,
    };
  }

  private createAccessToken(
    playerId: string,
    sessionId: string,
  ): Promise<string> {
    return this.jwtService.signAsync({
      sub: playerId,
      sid: sessionId,
    });
  }

  private createRefreshToken(): string {
    return randomBytes(64).toString('base64url');
  }

  private hashRefreshToken(refreshToken: string): string {
    return createHash('sha256').update(refreshToken).digest('hex');
  }

  private isValidAccessTokenPayload(
    payload: unknown,
  ): payload is AccessTokenPayload {
    return (
      typeof payload === 'object' &&
      payload !== null &&
      'sub' in payload &&
      typeof payload.sub === 'string' &&
      'sid' in payload &&
      typeof payload.sid === 'string' &&
      'exp' in payload &&
      typeof payload.exp === 'number' &&
      Number.isFinite(payload.exp)
    );
  }
}
