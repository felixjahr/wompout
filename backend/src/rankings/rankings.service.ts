import { Injectable, OnModuleInit } from '@nestjs/common';
import { auditTime } from 'rxjs';

import { PrismaService } from '../prisma/prisma.service';
import { PlayersService } from '../players/players.service';
import { RealtimeService } from '../realtime/realtime.service';
import { ResourceName } from '../realtime/realtime.types';
import { Rankings } from './rankings.types';

@Injectable()
export class RankingsService implements OnModuleInit {
  private queue: Promise<void> = Promise.resolve();

  constructor(
    private readonly prismaService: PrismaService,
    private readonly playersService: PlayersService,
    private readonly realtimeService: RealtimeService,
  ) {}

  onModuleInit(): void {
    this.realtimeService.registerSnapshotProvider(ResourceName.Rankings, () =>
      this.enqueue(() => this.getRankings()),
    );

    this.playersService.publicProfileChanged$
      .pipe(auditTime(1000))
      .subscribe(() => {
        void this.enqueue(() => this.publishRankings()).catch(console.error);
      });
  }

  private enqueue<T>(operation: () => Promise<T>): Promise<T> {
    const result = this.queue.then(operation);

    this.queue = result.then(
      () => undefined,
      () => undefined,
    );

    return result;
  }

  private async getRankings(): Promise<Rankings> {
    const progressions = await this.prismaService.playerProgression.findMany({
      take: 10,
      orderBy: [{ trophies: 'desc' }, { playerId: 'asc' }],
      select: {
        playerId: true,
        trophies: true,
        player: {
          select: {
            displayName: true,
          },
        },
      },
    });

    return {
      players: progressions.map((progression) => ({
        id: progression.playerId,
        displayName: progression.player.displayName,
        trophies: progression.trophies,
      })),
    };
  }

  private async publishRankings(): Promise<void> {
    const snapshot = await this.getRankings();
    this.realtimeService.publishToSubscribers(ResourceName.Rankings, snapshot);
  }
}
