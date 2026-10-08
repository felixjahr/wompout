import {
  ForbiddenException,
  Injectable,
  NotFoundException,
  OnModuleInit,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Player, PlayerLoadout } from './players.types';
import { RealtimeService } from '../realtime/realtime.service';
import { ResourceName } from '../realtime/realtime.types';
import { Subject } from 'rxjs';

@Injectable()
export class PlayersService implements OnModuleInit {
  private readonly publicProfileChangedSubject = new Subject<string>();
  readonly publicProfileChanged$ =
    this.publicProfileChangedSubject.asObservable();

  constructor(
    private readonly prismaService: PrismaService,
    private readonly realtimeService: RealtimeService,
  ) {}

  onModuleInit(): void {
    this.realtimeService.registerSnapshotProvider(
      ResourceName.Player,
      (playerId) => this.getPlayer(playerId),
    );
  }

  async updateEmail(playerId: string, email: string): Promise<void> {
    await this.prismaService.player.update({
      where: {
        id: playerId,
      },
      data: {
        email: email,
      },
    });
    await this.publishPlayer(playerId);
  }

  async updateTrophies(playerId: string, delta: number): Promise<number> {
    const actualChange = await this.prismaService.$transaction(
      async (tx) => {
        const progression = await tx.playerProgression.findUniqueOrThrow({
          where: { playerId },
        });

        const previousTrophies = progression.trophies;
        const newTrophies = Math.max(0, previousTrophies + delta);

        await tx.playerProgression.update({
          where: { playerId },
          data: {
            trophies: newTrophies,
            highestTrophies: Math.max(progression.highestTrophies, newTrophies),
          },
        });

        return newTrophies - previousTrophies;
      },
      { isolationLevel: 'Serializable' },
    );

    this.publicProfileChangedSubject.next(playerId);
    await this.publishPlayer(playerId);

    return actualChange;
  }

  async updateLoadout(
    playerId: string,
    loadout: PlayerLoadout,
  ): Promise<PlayerLoadout> {
    const requestedItems = [
      { itemType: 'RANGED' as const, itemId: loadout.rangedId },
      { itemType: 'MELEE' as const, itemId: loadout.meleeId },
      { itemType: 'ARMOUR' as const, itemId: loadout.armourId },
      { itemType: 'ABILITY' as const, itemId: loadout.abilityId },
    ];

    const savedLoadout = await this.prismaService.$transaction(async (tx) => {
      const ownedItems = await tx.playerItem.findMany({
        where: {
          playerId,
          OR: requestedItems,
        },
        select: {
          itemType: true,
          itemId: true,
        },
      });

      const ownsEveryItem = requestedItems.every((requested) =>
        ownedItems.some(
          (owned) =>
            owned.itemType === requested.itemType &&
            owned.itemId === requested.itemId,
        ),
      );

      if (!ownsEveryItem) {
        throw new ForbiddenException(
          'Loadout contains an item you do not own in that category',
        );
      }

      return tx.playerLoadout.update({
        where: { playerId },
        data: {
          rangedId: loadout.rangedId,
          meleeId: loadout.meleeId,
          armourId: loadout.armourId,
          abilityId: loadout.abilityId,
        },
        select: {
          rangedId: true,
          meleeId: true,
          armourId: true,
          abilityId: true,
        },
      });
    });

    try {
      await this.publishPlayer(playerId);
    } catch (error) {
      console.error('Failed to publish player after loadout change', error);
    }

    return savedLoadout;
  }

  async getPlayer(playerId: string): Promise<Player> {
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

  private async publishPlayer(playerId: string): Promise<void> {
    const player = await this.getPlayer(playerId);

    this.realtimeService.publishToPlayers(ResourceName.Player, player, [
      playerId,
    ]);
  }
}
