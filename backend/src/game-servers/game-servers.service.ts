import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { CompletedGame, Game, GameSpec } from './game-servers.types';
import { ConfigService } from '@nestjs/config';
import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';
import { spawn } from 'node:child_process';
import { GameResultsDto } from './dto/game-results.dto';
import { Subject } from 'rxjs';
import { PlayersService } from '../players/players.service';
import { MODES } from '../config/modes.config';
import { MatchesService } from '../matches/matches.service';

@Injectable()
export class GameServersService {
  private readonly games = new Map<string, Game>();
  private nextGamePort: number;

  private readonly completedGames = new Map<string, CompletedGame>();
  private readonly reportedResults = new Map<
    string,
    Map<string, Promise<void>>
  >();
  private readonly releasedPlayers = new Map<string, Set<string>>();

  private readonly gameClosedSubject = new Subject<string[]>();
  readonly gameClosed$ = this.gameClosedSubject.asObservable();

  constructor(
    private readonly configService: ConfigService,
    private readonly playersService: PlayersService,
    private readonly matchesService: MatchesService,
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
      this.matchesService.updateMatch(player.id, {
        gameId: game.id,
        modeId: game.modeId,
        mapId: game.mapId,
        status: 'ready',
        connection: {
          ip: game.ip,
          port: game.port,
          playerToken: game.playerTokens[player.id],
        },
      });
    }
  }

  async reportResults(gameId: string, request: GameResultsDto): Promise<void> {
    const game = this.games.get(gameId);

    if (!game) {
      const completed = this.completedGames.get(gameId);
      if (completed) return completed.completionPromise;

      throw new NotFoundException('Game not found');
    }

    const participants = [...game.players, ...game.bots];
    const teamCount = new Set(
      participants.map((participant) => participant.teamId),
    ).size;

    const results = request.results.map((result) => {
      const participant = participants.find(
        (participant) => participant.id === result.participantId,
      );

      if (!participant || result.placement > teamCount) {
        throw new BadRequestException('Invalid result');
      }

      return {
        participantId: participant.id,
        displayName: participant.displayName,
        teamId: participant.teamId,
        placement: result.placement,
        loadout: { ...result.loadout },
      };
    });

    const includedIds = new Set(results.map((result) => result.participantId));
    const includedTeams = new Set(results.map((result) => result.teamId));

    for (const participant of participants) {
      const required = teamCount === 2 || includedTeams.has(participant.teamId);

      if (required && !includedIds.has(participant.id)) {
        throw new BadRequestException('Incomplete team results');
      }
    }

    const mode = MODES[game.modeId as keyof typeof MODES];
    const players = game.players.filter((player) => includedIds.has(player.id));

    if (
      mode.ranked &&
      results.some(
        (result) => mode.trophyChanges[result.placement - 1] === undefined,
      )
    ) {
      throw new BadRequestException('Invalid trophy placement');
    }

    let reported = this.reportedResults.get(gameId);

    if (!reported) {
      reported = new Map();
      this.reportedResults.set(gameId, reported);
    }

    for (const player of players) {
      const existing = reported.get(player.id);

      if (existing) {
        await existing;
        continue;
      }

      const ownResult = results.find(
        (result) => result.participantId === player.id,
      )!;

      const operation = Promise.resolve().then(async () => {
        const trophyChange = mode.ranked
          ? await this.playersService.recordMatchResult(
              player.id,
              mode.trophyChanges[ownResult.placement - 1],
            )
          : null;

        if (this.games.get(gameId) !== game) return;

        this.matchesService.updateMatch(player.id, {
          gameId,
          modeId: game.modeId,
          mapId: game.mapId,
          status: 'completed',
          results:
            teamCount === 2
              ? results
              : results.filter((result) => result.teamId === player.teamId),
          trophyChange,
        });
      });

      reported.set(player.id, operation);
      await operation;
    }

    if (this.games.get(gameId) !== game) {
      return;
    }

    let released = this.releasedPlayers.get(gameId);

    if (!released) {
      released = new Set();
      this.releasedPlayers.set(gameId, released);
    }

    const newlyFinished = players
      .map((player) => player.id)
      .filter((playerId) => !released.has(playerId));

    for (const playerId of newlyFinished) {
      released.add(playerId);
    }

    if (newlyFinished.length > 0) {
      this.gameClosedSubject.next(newlyFinished);
    }
  }

  async endGame(gameId: string): Promise<void> {
    const existing = this.completedGames.get(gameId);
    if (existing) return existing.completionPromise;

    const game = this.games.get(gameId);
    if (!game) throw new NotFoundException('Game not found');

    const released = this.releasedPlayers.get(gameId);

    if (game.players.some((player) => !released?.has(player.id))) {
      throw new BadRequestException('Report all player results first');
    }

    const completed: CompletedGame = {
      id: gameId,
      callbackTokenHash: game.callbackTokenHash,
      expiresAt: Infinity,
      completionPromise: Promise.resolve(),
    };

    this.completedGames.set(gameId, completed);

    if (game.startupTimer) {
      clearTimeout(game.startupTimer);
    }

    this.games.delete(gameId);

    const retentionMs = 10 * 60 * 1000;
    completed.expiresAt = Date.now() + retentionMs;

    setTimeout(() => {
      this.completedGames.delete(gameId);
      this.reportedResults.delete(gameId);
      this.releasedPlayers.delete(gameId);
    }, retentionMs).unref();
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

    this.matchesService.assignMatch(
      gameSpec.players.map((player) => player.id),
      {
        gameId: gameSpec.id,
        modeId: gameSpec.modeId,
        mapId: gameSpec.mapId,
        status: 'starting',
      },
    );

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

    game.status = 'failed';
    this.games.delete(gameId);

    if (game.startupTimer) {
      clearTimeout(game.startupTimer);
    }

    const released = this.releasedPlayers.get(gameId);
    const unfinishedPlayers = game.players.filter(
      (player) => !released?.has(player.id),
    );

    for (const player of unfinishedPlayers) {
      this.matchesService.updateMatch(player.id, {
        gameId,
        modeId: game.modeId,
        mapId: game.mapId,
        status: 'failed',
        reason,
      });
    }

    if (unfinishedPlayers.length > 0) {
      this.gameClosedSubject.next(unfinishedPlayers.map((player) => player.id));
    }

    this.reportedResults.delete(gameId);
    this.releasedPlayers.delete(gameId);

    const stop = spawn('docker', ['stop', gameId], {
      stdio: 'ignore',
    });

    stop.once('error', (error) => {
      console.error(`Failed to stop game ${gameId}:`, error);
    });
  }
}
