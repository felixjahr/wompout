import { Injectable, NotFoundException, OnModuleInit } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Player } from './players.types';
import { RealtimeService } from '../realtime/realtime.service';
import { AuthService } from '../auth/auth.service';
import { merge } from 'rxjs';

@Injectable()
export class PlayersService implements OnModuleInit {
  constructor(
    private readonly prismaService: PrismaService,
    private readonly realtimeService: RealtimeService,
    private readonly authService: AuthService,
  ) {}

  onModuleInit(): void {
    merge(
      this.realtimeService.connected$,
      this.authService.playerChanged$,
    ).subscribe((playerId) => {
      if (!this.realtimeService.isPlayerConnected(playerId)) return;

      void this.getPlayerForPlayer(playerId)
        .then((player) => this.sendPlayerToPlayer(playerId, player))
        .catch(console.error);
    });
  }

  async getPlayerForPlayer(playerId: string): Promise<Player> {
    const player = await this.prismaService.player.findUnique({
      where: { id: playerId },
      include: {
        progression: true,
        loadout: true,
        items: true,
      },
    });

    if (!player || !player.progression || !player.loadout) {
      throw new NotFoundException('Player not found');
    }

    return {
      id: player.id,
      displayName: player.displayName,
      email: player.email,
      trophies: player.progression.trophies,
      highestTrophies: player.progression.highestTrophies,
      loadout: {
        rangedId: player.loadout.rangedId,
        meleeId: player.loadout.meleeId,
        armourId: player.loadout.armourId,
        abilityId: player.loadout.abilityId,
      },
      items: player.items.map((item) => ({
        itemType: item.itemType,
        itemId: item.itemId,
        unlockedAt: item.unlockedAt.toISOString(),
      })),
    };
  }

  private sendPlayerToPlayer(playerId: string, player: Player): void {
    this.realtimeService.sendToPlayer(playerId, 'playerUpdated', { player });
  }

  private async updatePlayer(playerId: string): Promise<void> {
    if (!this.realtimeService.isPlayerConnected(playerId)) return;

    const player = await this.getPlayerForPlayer(playerId);
    this.sendPlayerToPlayer(playerId, player);
  }
}
