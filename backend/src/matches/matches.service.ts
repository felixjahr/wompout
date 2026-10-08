import { ConflictException, Injectable, OnModuleInit } from '@nestjs/common';
import { RealtimeService } from '../realtime/realtime.service';
import { ResourceName } from '../realtime/realtime.types';
import { Match } from './matches.types';

type StartingMatch = Extract<Match, { status: 'starting' }>;
type MatchUpdate = Exclude<Match, { status: 'starting' }>;

@Injectable()
export class MatchesService implements OnModuleInit {
  private readonly matchByPlayerId = new Map<string, Match>();

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

      if (current && current.gameId !== match.gameId) {
        throw new ConflictException(
          'Player already has an active or unacknowledged match',
        );
      }
    }

    for (const playerId of uniquePlayerIds) {
      if (this.matchByPlayerId.has(playerId)) continue;

      this.matchByPlayerId.set(playerId, structuredClone(match));

      this.publishMatch(playerId);
    }
  }

  updateMatch(playerId: string, match: MatchUpdate): void {
    const current = this.matchByPlayerId.get(playerId);

    if (!current || current.gameId !== match.gameId) {
      return;
    }

    if (current.status === 'completed' || current.status === 'failed') {
      return;
    }

    this.matchByPlayerId.set(playerId, structuredClone(match));

    this.publishMatch(playerId);
  }

  acknowledgeMatch(playerId: string, gameId: string): void {
    const current = this.matchByPlayerId.get(playerId);

    if (!current || current.gameId !== gameId) return;

    if (current.status !== 'completed' && current.status !== 'failed') {
      throw new ConflictException('Match has not finished');
    }

    this.matchByPlayerId.delete(playerId);
    this.publishMatch(playerId);
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
