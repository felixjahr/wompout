import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { CompletedGame, Game, GameSpec } from './game-servers.types';
import { ConfigService } from '@nestjs/config';
import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';
import { spawn } from 'node:child_process';
import { EndGameRequestDto } from './dto/end-game-request.dto';
import { RealtimeService } from '../realtime/realtime.service';
import { Subject } from 'rxjs';
import { PrismaService } from '../prisma/prisma.service';
import { PlayersService } from '../players/players.service';
import { MODES } from '../config/modes.config';

@Injectable()
export class GameServersService {
  private readonly games = new Map<string, Game>();
  private nextGamePort: number;
  private readonly completedGames = new Map<string, CompletedGame>();

  private readonly gameClosedSubject = new Subject<string[]>();
  readonly gameClosed$ = this.gameClosedSubject.asObservable();

  constructor(
    private readonly configService: ConfigService,
    private readonly realtimeService: RealtimeService,
    private readonly prismaService: PrismaService,
    private readonly playersService: PlayersService,
  ) {
    this.nextGamePort = Number(
      this.configService.getOrThrow<string>('GAME_BASE_PORT'),
    );
  }

  markGameReady(gameId: string): void {
    const game = this.games.get(gameId);
    if (!game) {
      throw new NotFoundException('Game not found');
    }

    if (game.status === 'ready') {
      return;
    }

    if (game.status !== 'starting') {
      throw new BadRequestException('Game is not starting');
    }

    if (game.startupTimer) {
      clearTimeout(game.startupTimer);
      delete game.startupTimer;
    }

    game.status = 'ready';

    for (const player of game.players) {
      this.realtimeService.sendToPlayer(player.id, 'gameReady', {
        ip: game.ip,
        port: game.port,
        playerToken: game.playerTokens[player.id],
      });
    }
  }

  async endGame(gameId: string, request: EndGameRequestDto): Promise<void> {
    const existing = this.completedGames.get(gameId);
    if (existing && existing.expiresAt > Date.now()) {
      return existing.completionPromise;
    }

    const game = this.games.get(gameId);
    if (!game) {
      throw new NotFoundException('Game not found');
    }

    const mode = MODES[game.modeId as keyof typeof MODES];

    const participants = new Map(
      [...game.players, ...game.bots].map((participant) => [
        participant.id,
        participant,
      ]),
    );

    const results = request.results.map((result) => {
      const participant = participants.get(result.participantId)!;

      return {
        participantId: participant.id,
        displayName: participant.displayName,
        teamId: participant.teamId,
        placement: result.placement,
        loadout: { ...result.loadout },
      };
    });

    const placementById = new Map(
      results.map((result) => [result.participantId, result.placement]),
    );

    const completed: CompletedGame = {
      id: gameId,
      callbackTokenHash: game.callbackTokenHash,
      expiresAt: Infinity,
      completionPromise: Promise.resolve(),
    };

    this.completedGames.set(gameId, completed);

    completed.completionPromise = Promise.resolve().then(async () => {
      let trophyChanges = new Map<string, number>();

      if (mode.ranked) {
        const configuredChanges: readonly number[] = mode.trophyChanges;

        trophyChanges = await this.prismaService
          .$transaction(
            async (tx) => {
              const changes = new Map<string, number>();

              const players = [...game.players].sort((a, b) =>
                a.id.localeCompare(b.id),
              );

              for (const player of players) {
                const placement = placementById.get(player.id)!;
                const change = configuredChanges[placement - 1];

                if (change === undefined) {
                  throw new BadRequestException(
                    'Missing trophy configuration for placement',
                  );
                }

                const progression =
                  await tx.playerProgression.findUniqueOrThrow({
                    where: { playerId: player.id },
                  });

                const trophies = Math.max(0, progression.trophies + change);

                await tx.playerProgression.update({
                  where: { playerId: player.id },
                  data: {
                    trophies,
                    highestTrophies: Math.max(
                      progression.highestTrophies,
                      trophies,
                    ),
                  },
                });

                changes.set(player.id, trophies - progression.trophies);
              }

              return changes;
            },
            { isolationLevel: 'Serializable' },
          )
          .catch((error: unknown) => {
            this.completedGames.delete(gameId);
            throw error;
          });
      }

      const retentionMs = 10 * 60 * 1000;
      completed.expiresAt = Date.now() + retentionMs;

      const timer = setTimeout(() => {
        this.completedGames.delete(gameId);
      }, retentionMs);

      timer.unref();

      if (game.startupTimer) {
        clearTimeout(game.startupTimer);
        delete game.startupTimer;
      }

      this.games.delete(gameId);

      if (mode.ranked) {
        for (const participant of game.players) {
          try {
            const player = await this.playersService.getPlayerForPlayer(
              participant.id,
            );

            this.realtimeService.sendToPlayer(participant.id, 'playerUpdated', {
              player,
            });
          } catch (error) {
            console.error('Failed to send playerUpdated', error);
          }
        }
      }

      this.gameClosedSubject.next(game.players.map((player) => player.id));

      for (const player of game.players) {
        try {
          if (mode.ranked) {
            this.realtimeService.sendToPlayer(player.id, 'gameOver', {
              gameId,
              results,
              ranked: true,
              trophyChange: trophyChanges.get(player.id)!,
            });
          } else {
            this.realtimeService.sendToPlayer(player.id, 'gameOver', {
              gameId,
              results,
              ranked: false,
            });
          }
        } catch (error) {
          console.error('Failed to send gameOver', error);
        }
      }
    });

    return completed.completionPromise;
  }

  startGame(gameSpec: GameSpec): void {
    if (this.games.has(gameSpec.id)) {
      throw new BadRequestException('Game session already exists');
    }

    const playerTokens: Record<string, string> = Object.fromEntries(
      gameSpec.players.map((player) => [
        player.id,
        randomBytes(64).toString('base64url'),
      ]),
    );
    const playerTokenHashes: Record<string, string> = Object.fromEntries(
      Object.entries(playerTokens).map(([playerId, token]) => [
        playerId,
        createHash('sha256').update(token).digest('hex'),
      ]),
    );

    const callbackToken = this.createCallbackToken();
    const callbackTokenHash = this.hashCallbackToken(callbackToken);

    const ip = this.configService.getOrThrow<string>('GAME_IP');
    const port = this.allocatePort();

    const game: Game = {
      ...gameSpec,
      status: 'starting',
      ip,
      port,
      playerTokens,
      callbackTokenHash,
    };

    game.startupTimer = setTimeout(
      () => {
        const currentGame = this.games.get(gameSpec.id);
        if (!currentGame || currentGame.status !== 'starting') return;
        this.failGame(gameSpec.id);
      },
      Number(this.configService.getOrThrow<string>('GAME_START_TIMEOUT_MS')),
    );

    this.games.set(gameSpec.id, game);

    const serverConfig = {
      gameId: game.id,
      modeId: game.modeId,
      mapId: game.mapId,
      port: game.port,
      players: game.players,
      bots: game.bots,
      playerTokenHashes,
      callbackToken,
      backendUrl: this.configService.getOrThrow<string>('BACKEND_INTERNAL_URL'),
    };

    const args = [
      'run',
      '--rm',

      '--name',
      gameSpec.id,

      '--platform',
      this.configService.getOrThrow<string>('GAME_SERVER_PLATFORM'),

      '--network',
      this.configService.getOrThrow<string>('GAME_SERVER_NETWORK'),

      '-p',
      `${port}:${port}/udp`,

      '-e',
      `SERVER_CONFIG=${JSON.stringify(serverConfig)}`,

      this.configService.getOrThrow<string>('GAME_SERVER_IMAGE'),
    ];

    const child = spawn('docker', args, { stdio: 'inherit' });

    const handleFailure = () => {
      const completedGame = this.completedGames.get(game.id);

      if (completedGame) {
        void completedGame.completionPromise.catch(() => {
          if (this.games.get(game.id) === game) {
            this.failGame(game.id);
          }
        });
        return;
      }

      if (this.games.get(game.id) === game) {
        this.failGame(game.id);
      }
    };

    child.once('error', handleFailure);
    child.once('close', handleFailure);
  }

  verifyCallbackToken(gameId: string, callbackToken: string): boolean {
    const game = this.games.get(gameId);
    const completedGame = this.completedGames.get(gameId);

    const expectedHash =
      game?.callbackTokenHash ??
      (completedGame && completedGame.expiresAt > Date.now()
        ? completedGame.callbackTokenHash
        : undefined);

    if (!expectedHash) return false;

    const actual = Buffer.from(this.hashCallbackToken(callbackToken));
    const expected = Buffer.from(expectedHash);

    return timingSafeEqual(actual, expected);
  }

  sendActiveGameToPlayer(playerId: string): void {
    for (const game of this.games.values()) {
      if (game.status !== 'ready') continue;
      if (!game.players.some((player) => player.id === playerId)) continue;

      this.realtimeService.sendToPlayer(playerId, 'gameReady', {
        ip: game.ip,
        port: game.port,
        playerToken: game.playerTokens[playerId],
      });
      return;
    }
  }

  private createCallbackToken(): string {
    return randomBytes(64).toString('base64url');
  }

  private hashCallbackToken(secret: string): string {
    return createHash('sha256').update(secret).digest('hex');
  }

  private allocatePort(): number {
    const gameBasePort = Number(
      this.configService.getOrThrow<string>('GAME_BASE_PORT'),
    );
    const gamePortRangeSize = Number(
      this.configService.getOrThrow<string>('GAME_PORT_RANGE_SIZE'),
    );
    const port = this.nextGamePort;
    this.nextGamePort =
      gameBasePort +
      ((this.nextGamePort - gameBasePort + 1) % gamePortRangeSize);
    return port;
  }

  private failGame(gameId: string): void {
    const game = this.games.get(gameId);
    if (!game) return;

    const reason =
      game.status === 'starting'
        ? 'Game server failed to start'
        : 'Game server stopped unexpectedly';

    this.games.delete(game.id);
    game.status = 'failed';

    if (game.startupTimer) {
      clearTimeout(game.startupTimer);
      delete game.startupTimer;
    }

    for (const player of game.players) {
      this.realtimeService.sendToPlayer(player.id, 'gameFailed', {
        reason,
      });
    }

    this.gameClosedSubject.next(game.players.map((player) => player.id));

    const stop = spawn('docker', ['stop', gameId], {
      stdio: 'ignore',
    });

    stop.once('error', (error) => {
      console.error(`Failed to run Docker stop for ${gameId}:`, error);
    });
  }
}
