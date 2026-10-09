import {
  BadRequestException,
  GoneException,
  HttpStatus,
  Injectable,
  NotFoundException,
  OnModuleInit,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import { CreateFriendInviteResponseDto } from './dto/create-friend-invite-response.dto';
import { createHash, randomBytes } from 'node:crypto';
import type { Request, Response } from 'express';
import { RealtimeService } from '../realtime/realtime.service';
import { LobbiesService } from '../lobbies/lobbies.service';
import { Friends } from './friends.types';
import { ResourceName } from '../realtime/realtime.types';
import { PlayersService } from '../players/players.service';

@Injectable()
export class FriendsService implements OnModuleInit {
  constructor(
    private readonly configService: ConfigService,
    private readonly prismaService: PrismaService,
    private readonly realtimeService: RealtimeService,
    private readonly lobbiesService: LobbiesService,
    private readonly playersService: PlayersService,
  ) {}

  onModuleInit(): void {
    this.realtimeService.registerSnapshotProvider(
      ResourceName.Friends,
      (playerId) => this.getFriendsForPlayer(playerId),
    );

    this.lobbiesService.playerLobbyStatusChanged$.subscribe((playerIds) => {
      for (const playerId of new Set(playerIds)) {
        void this.publishFriendsToFriendsOf(playerId).catch(console.error);
      }
    });

    this.playersService.publicProfileChanged$.subscribe((playerId) => {
      void this.publishFriendsToFriendsOf(playerId).catch(console.error);
    });
  }

  async createInvite(
    inviterId: string,
  ): Promise<CreateFriendInviteResponseDto> {
    const token = this.createToken();
    const expiresAt = new Date(
      Date.now() +
        Number(
          this.configService.getOrThrow<string>('FRIEND_INVITE_EXPIRATION_MS'),
        ),
    );

    await this.prismaService.friendInvite.create({
      data: {
        inviterId,
        tokenHash: this.hashToken(token),
        expiresAt,
      },
    });

    const baseUrl = this.configService.getOrThrow<string>(
      'FRIEND_INVITE_BASE_URL',
    );

    return {
      invite_url: `${baseUrl}/friends/invite/${token}`,
    };
  }

  async redeemInvite(playerId: string, token: string): Promise<void> {
    const invite = await this.prismaService.friendInvite.findUnique({
      where: {
        tokenHash: this.hashToken(token),
      },
    });

    if (!invite) {
      throw new NotFoundException('Invite not found');
    }

    if (invite.expiresAt <= new Date()) {
      throw new GoneException('Invite expired');
    }

    if (invite.inviterId === playerId) {
      throw new BadRequestException('You can not redeem your own invite');
    }

    const [playerAId, playerBId] =
      invite.inviterId < playerId
        ? [invite.inviterId, playerId]
        : [playerId, invite.inviterId];

    await this.prismaService.friendship.upsert({
      where: {
        playerAId_playerBId: {
          playerAId,
          playerBId,
        },
      },
      update: {},
      create: {
        playerAId,
        playerBId,
      },
    });

    await Promise.all([
      this.publishFriends(playerId),
      this.publishFriends(invite.inviterId),
    ]).catch(console.error);
  }

  async openInvite(
    token: string,
    request: Request,
    response: Response,
  ): Promise<void> {
    const invite = await this.prismaService.friendInvite.findUnique({
      where: {
        tokenHash: this.hashToken(token),
      },
      select: {
        expiresAt: true,
      },
    });

    if (!invite || invite.expiresAt <= new Date()) {
      response.status(410).type('html').send(`
        <!doctype html>
        <script>
          alert("This invite is invalid or has expired. Ask your friend for a new link.");
        </script>
      `);
      return;
    }

    const userAgent = request.headers['user-agent'] ?? '';
    let storeUrl: string;
    if (/android/i.test(userAgent)) {
      storeUrl = this.configService.getOrThrow<string>(
        'ANDROID_PLAY_STORE_URL',
      );
    } else {
      storeUrl = this.configService.getOrThrow<string>('IOS_APP_STORE_URL');
    }

    response.redirect(HttpStatus.FOUND, storeUrl);
  }

  async getFriendsForPlayer(playerId: string): Promise<Friends> {
    const friendships = await this.prismaService.friendship.findMany({
      where: {
        OR: [{ playerAId: playerId }, { playerBId: playerId }],
      },
      select: {
        playerA: {
          select: {
            id: true,
            displayName: true,
            progression: { select: { trophies: true } },
          },
        },
        playerB: {
          select: {
            id: true,
            displayName: true,
            progression: { select: { trophies: true } },
          },
        },
      },
      orderBy: { id: 'asc' },
    });

    const players = friendships.map((friendship) => {
      const friend =
        friendship.playerA.id === playerId
          ? friendship.playerB
          : friendship.playerA;

      return {
        id: friend.id,
        displayName: friend.displayName,
        trophies: friend.progression!.trophies,
        status: this.lobbiesService.getPlayerLobbyStatus(friend.id),
      };
    });

    return { players };
  }

  private createToken(): string {
    return randomBytes(64).toString('base64url');
  }

  private hashToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }

  private async publishFriends(playerId: string): Promise<void> {
    const snapshot = await this.getFriendsForPlayer(playerId);

    this.realtimeService.publishToPlayers(ResourceName.Friends, snapshot, [
      playerId,
    ]);
  }

  private async publishFriendsToFriendsOf(playerId: string): Promise<void> {
    const friendships = await this.prismaService.friendship.findMany({
      where: {
        OR: [{ playerAId: playerId }, { playerBId: playerId }],
      },
      select: {
        playerAId: true,
        playerBId: true,
      },
    });

    const friendIds = new Set(
      friendships.map((friendship) =>
        friendship.playerAId === playerId
          ? friendship.playerBId
          : friendship.playerAId,
      ),
    );

    await Promise.all(
      [...friendIds].map((friendId) => this.publishFriends(friendId)),
    );
  }
}
