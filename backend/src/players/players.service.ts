import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  OnModuleInit,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { ChestContent, Player, PlayerLoadout } from './players.types';
import { RealtimeService } from '../realtime/realtime.service';
import { ResourceName } from '../realtime/realtime.types';
import { Subject } from 'rxjs';
import { PlayerProgression } from '../../generated/prisma/client';
import {
  CHEST_REWARDS,
  CHEST_ITEM_GROUPS,
  CurrencyRollConfig,
  DAILY_BONUS_PROGRESS,
  DAILY_BONUS_WINS,
  INTRO_CHEST_REQUIREMENTS,
  REGULAR_CHEST_REQUIREMENT,
} from '../config/chest.config';

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

  async openChest(playerId: string): Promise<ChestContent> {
    const content = await this.prismaService.$transaction(
      async (tx) => {
        const progression = await tx.playerProgression.findUniqueOrThrow({
          where: { playerId },
        });

        const required = this.getChestRequirement(
          progression.introChestsOpened,
        );

        if (progression.chestProgress < required) {
          throw new BadRequestException('Not enough progress to open a chest');
        }

        const ownedItems = await tx.playerItem.findMany({
          where: { playerId },
          select: { itemId: true },
        });

        const introCount = INTRO_CHEST_REQUIREMENTS.length;
        const isIntroChest = progression.introChestsOpened < introCount;
        const reward = this.rollChestReward(
          ownedItems.map((item) => item.itemId),
          isIntroChest,
        );

        const now = new Date();
        const introChestsOpened =
          progression.introChestsOpened + (isIntroChest ? 1 : 0);

        const justFinishedIntro =
          isIntroChest && introChestsOpened === introCount;

        const bonus = justFinishedIntro
          ? {
              dailyBonusWinsRemaining: 0,
              nextDailyBonusAt: this.getNextDailyReset(now),
            }
          : this.resolveDailyBonus(progression, now);

        await tx.playerProgression.update({
          where: { playerId },
          data: {
            chestProgress: progression.chestProgress - required,
            introChestsOpened,
            ...bonus,
            coins: {
              increment: reward.type === 'coins' ? reward.amount : 0,
            },
            gems: {
              increment: reward.type === 'gems' ? reward.amount : 0,
            },
          },
        });

        if (reward.type === 'item') {
          await tx.playerItem.create({
            data: {
              playerId,
              itemId: reward.itemId,
            },
          });
        }

        return reward;
      },
      { isolationLevel: 'Serializable' },
    );

    try {
      await this.publishPlayer(playerId);
    } catch (error) {
      console.error('Failed to publish player after opening chest', error);
    }

    return content;
  }

  private rollChestReward(
    ownedItemIds: string[],
    itemsOnly = false,
  ): ChestContent {
    const owned = new Set(ownedItemIds);
    const availableGroups = CHEST_ITEM_GROUPS.map((group) => ({
      weight: group.weight,
      items: group.items.filter((itemId) => !owned.has(itemId)),
    })).filter((group) => group.weight > 0 && group.items.length > 0);

    if (itemsOnly && availableGroups.length > 0) {
      const group = this.pickWeighted(availableGroups);
      const itemId =
        group.items[Math.floor(Math.random() * group.items.length)];
      return { type: 'item', itemId };
    }

    const outcomes: {
      type: 'coins' | 'gems' | 'items';
      weight: number;
    }[] = [
      { type: 'coins', weight: CHEST_REWARDS.coins.weight },
      { type: 'gems', weight: CHEST_REWARDS.gems.weight },
    ];

    if (availableGroups.length > 0) {
      outcomes.push({
        type: 'items',
        weight: CHEST_REWARDS.items.weight,
      });
    }

    const outcome = this.pickWeighted(outcomes);

    if (outcome.type === 'coins' || outcome.type === 'gems') {
      return {
        type: outcome.type,
        amount: this.rollCurrency(CHEST_REWARDS[outcome.type].amount),
      };
    }

    const group = this.pickWeighted(availableGroups);
    const item = group.items[Math.floor(Math.random() * group.items.length)];

    return {
      type: 'item',
      itemId: item,
    };
  }

  private pickWeighted<T extends { weight: number }>(options: readonly T[]): T {
    if (
      options.some(
        (option) => !Number.isFinite(option.weight) || option.weight < 0,
      )
    ) {
      throw new Error('Chest weights must be finite and non-negative');
    }

    const eligible = options.filter((option) => option.weight > 0);
    const total = eligible.reduce((sum, option) => sum + option.weight, 0);

    if (eligible.length === 0 || !Number.isFinite(total)) {
      throw new Error('No valid chest reward options');
    }

    let roll = Math.random() * total;

    for (const option of eligible) {
      roll -= option.weight;

      if (roll < 0) {
        return option;
      }
    }

    return eligible[eligible.length - 1];
  }

  async recordMatchResult(
    playerId: string,
    trophyDelta: number,
  ): Promise<number> {
    const actualChange = await this.prismaService.$transaction(
      async (tx) => {
        const progression = await tx.playerProgression.findUniqueOrThrow({
          where: { playerId },
        });

        const bonus = this.resolveDailyBonus(progression, new Date());
        const usesBonus = trophyDelta > 0 && bonus.dailyBonusWinsRemaining > 0;
        const progressGained =
          trophyDelta > 0 ? (usesBonus ? DAILY_BONUS_PROGRESS : 1) : 0;

        const trophies = Math.max(0, progression.trophies + trophyDelta);

        await tx.playerProgression.update({
          where: { playerId },
          data: {
            trophies,
            highestTrophies: Math.max(progression.highestTrophies, trophies),
            chestProgress: progression.chestProgress + progressGained,
            dailyBonusWinsRemaining:
              bonus.dailyBonusWinsRemaining - (usesBonus ? 1 : 0),
            nextDailyBonusAt: bonus.nextDailyBonusAt,
          },
        });

        return trophies - progression.trophies;
      },
      { isolationLevel: 'Serializable' },
    );

    this.publicProfileChangedSubject.next(playerId);
    await this.publishPlayer(playerId);

    return actualChange;
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

  async updateLoadout(
    playerId: string,
    loadout: PlayerLoadout,
  ): Promise<PlayerLoadout> {
    const requestedItems = [
      loadout.rangedId,
      loadout.meleeId,
      loadout.armourId,
      loadout.abilityId,
      loadout.styleId,
    ];

    const savedLoadout = await this.prismaService.$transaction(async (tx) => {
      const ownedItems = await tx.playerItem.findMany({
        where: {
          playerId,
          itemId: { in: requestedItems },
        },
        select: {
          itemId: true,
        },
      });

      const ownedIds = new Set(ownedItems.map((item) => item.itemId));
      const ownsEveryItem = requestedItems.every((itemId) =>
        ownedIds.has(itemId),
      );

      if (!ownsEveryItem) {
        throw new ForbiddenException('Loadout contains an item you do not own');
      }

      return tx.playerLoadout.update({
        where: { playerId },
        data: {
          rangedId: loadout.rangedId,
          meleeId: loadout.meleeId,
          armourId: loadout.armourId,
          abilityId: loadout.abilityId,
          styleId: loadout.styleId,
        },
        select: {
          rangedId: true,
          meleeId: true,
          armourId: true,
          abilityId: true,
          styleId: true,
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

  private rollCurrency({ min, max, k }: CurrencyRollConfig): number {
    const u = Math.random();

    const x = max - (max - min) * Math.pow(1 - u, 1 / (k + 1));

    return Math.max(min, Math.min(max, Math.round(x)));
  }

  private getNextDailyReset(now: Date): Date {
    return new Date(
      Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + 1),
    );
  }

  private resolveDailyBonus(progression: PlayerProgression, now: Date) {
    const { nextDailyBonusAt, dailyBonusWinsRemaining } = progression;

    if (nextDailyBonusAt === null) {
      return {
        dailyBonusWinsRemaining: 0,
        nextDailyBonusAt: null,
      };
    }

    if (now >= nextDailyBonusAt) {
      return {
        dailyBonusWinsRemaining: DAILY_BONUS_WINS,
        nextDailyBonusAt: this.getNextDailyReset(now),
      };
    }

    return { dailyBonusWinsRemaining, nextDailyBonusAt };
  }

  private getChestRequirement(introChestsOpened: number): number {
    return 0;
    // return (
    //   INTRO_CHEST_REQUIREMENTS[introChestsOpened] ?? REGULAR_CHEST_REQUIREMENT
    // );
  }

  private getReadyChestCount(progression: PlayerProgression): number {
    let progress = progression.chestProgress;
    let introIndex = progression.introChestsOpened;
    let readyChests = 0;

    while (introIndex < INTRO_CHEST_REQUIREMENTS.length) {
      const required = this.getChestRequirement(introIndex);

      if (progress < required) {
        return readyChests;
      }

      progress -= required;
      readyChests++;
      introIndex++;
    }

    return readyChests + Math.floor(progress / REGULAR_CHEST_REQUIREMENT);
  }

  private buildChestSnapshot(
    progression: PlayerProgression,
    now: Date,
  ): Player['chestProgress'] {
    const bonus = this.resolveDailyBonus(progression, now);

    return {
      progress: progression.chestProgress,
      requiredProgress: this.getChestRequirement(progression.introChestsOpened),
      readyChests: this.getReadyChestCount(progression),
      dailyBonusWinsRemaining: bonus.dailyBonusWinsRemaining,
      nextDailyBonusAt: bonus.nextDailyBonusAt?.toISOString() ?? null,
    };
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
      coins: player.progression.coins,
      gems: player.progression.gems,
      chestProgress: this.buildChestSnapshot(player.progression, new Date()),
      loadout: {
        rangedId: player.loadout.rangedId,
        meleeId: player.loadout.meleeId,
        armourId: player.loadout.armourId,
        abilityId: player.loadout.abilityId,
        styleId: player.loadout.styleId,
      },
      items: player.items.map((item) => ({
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
