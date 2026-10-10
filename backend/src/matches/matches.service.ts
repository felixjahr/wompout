import { ConflictException, Injectable, OnModuleInit } from '@nestjs/common';
import { RealtimeService } from '../realtime/realtime.service';
import { ResourceName } from '../realtime/realtime.types';
import { Match } from './matches.types';

type StartingMatch = Extract<Match, { status: 'starting' }>;
type MatchUpdate = Exclude<Match, { status: 'starting' }>;

const RESULT_RETENTION_MS = 10 * 60 * 1000;

@Injectable()
export class MatchesService implements OnModuleInit {
  private readonly matchByPlayerId = new Map<string, Match>();
  private readonly expiryTimers = new Map<
    string,
    ReturnType<typeof setTimeout>
  >();

  constructor(private readonly realtimeService: RealtimeService) {}

  onModuleInit(): void {
    this.realtimeService.registerSnapshotProvider(
      ResourceName.Match,
      (playerId) => this.getMatch(playerId),
    );
  }

  assignMatch(playerIds: readonly string[], match: StartingMatch): void {
    const uniquePlayerIds = [...new Set(playerIds)];

    for (const playerId of uniquePlayerIds) {
      const current = this.matchByPlayerId.get(playerId);

      if (
        current &&
        current.gameId !== match.gameId &&
        !this.isFinished(current)
      ) {
        throw new ConflictException('Player already has an active match');
      }
    }

    for (const playerId of uniquePlayerIds) {
      const current = this.matchByPlayerId.get(playerId);

      if (current?.gameId === match.gameId) continue;

      this.clearExpiry(playerId);
      this.matchByPlayerId.set(playerId, structuredClone(match));
      this.publishMatch(playerId);
    }
  }

  updateMatch(playerId: string, match: MatchUpdate): void {
    const current = this.matchByPlayerId.get(playerId);

    if (!current || current.gameId !== match.gameId) {
      return;
    }

    if (this.isFinished(current)) return;

    this.matchByPlayerId.set(playerId, structuredClone(match));

    if (this.isFinished(match)) {
      this.scheduleExpiry(playerId, match.gameId);
    }

    this.publishMatch(playerId);
  }

  acknowledgeMatch(playerId: string, gameId: string): void {
    const current = this.matchByPlayerId.get(playerId);

    if (!current || current.gameId !== gameId) return;

    if (!this.isFinished(current)) {
      throw new ConflictException('Match has not finished');
    }

    this.clearExpiry(playerId);
    this.matchByPlayerId.delete(playerId);
    this.publishMatch(playerId);
  }

  private scheduleExpiry(playerId: string, gameId: string): void {
    this.clearExpiry(playerId);

    const timer = setTimeout(() => {
      const current = this.matchByPlayerId.get(playerId);

      if (current?.gameId === gameId && this.isFinished(current)) {
        this.clearExpiry(playerId);
        this.matchByPlayerId.delete(playerId);
        this.publishMatch(playerId);
      }
    }, RESULT_RETENTION_MS);

    timer.unref();
    this.expiryTimers.set(playerId, timer);
  }

  private clearExpiry(playerId: string): void {
    const timer = this.expiryTimers.get(playerId);

    if (timer !== undefined) {
      clearTimeout(timer);
      this.expiryTimers.delete(playerId);
    }
  }

  private isFinished(match: Match): boolean {
    return match.status === 'completed' || match.status === 'failed';
  }

  private getMatch(playerId: string): Match | null {
    const match = this.matchByPlayerId.get(playerId);

    return match ? structuredClone(match) : null;
  }

  private publishMatch(playerId: string): void {
    this.realtimeService.publishToPlayers(
      ResourceName.Match,
      this.getMatch(playerId),
      [playerId],
    );
  }
}
