import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  OnModuleInit,
} from '@nestjs/common';
import {
  Lobby,
  LobbyInvite,
  LobbyInviteSnapshot,
  LobbyPlayer,
} from './lobbies.types';
import { randomUUID } from 'node:crypto';
import {
  DEFAULT_MODE_ID_BY_LOBBY_SIZE,
  MAX_LOBBY_PLAYERS,
  MODES,
} from '../config/modes.config';
import { UpdateReadyRequestDto } from './dto/update-ready-request.dto';
import { UpdateModeRequestDto } from './dto/update-mode-request.dto';
import { InvitePlayerRequestDto } from './dto/invite-player-request.dto';
import { RealtimeService } from '../realtime/realtime.service';
import { MatchmakingService } from '../matchmaking/matchmaking.service';
import { GameServersService } from '../game-servers/game-servers.service';
import { Subject } from 'rxjs';
import { ResourceName } from '../realtime/realtime.types';
import { WsException } from '@nestjs/websockets';
import { PlayersService } from '../players/players.service';
import { UpdateLoadoutRequestDto } from './dto/update-loadout-request.dto';

@Injectable()
export class LobbiesService implements OnModuleInit {
  private readonly lobbies = new Map<string, Lobby>();
  private readonly lobbyIdByPlayerId = new Map<string, string>();

  private readonly invites = new Map<string, LobbyInvite>();
  private readonly inviteIdsBySourcePlayerId = new Map<string, Set<string>>();
  private readonly inviteIdsByInvitedPlayerId = new Map<string, Set<string>>();

  private readonly playerLobbyStatusChangedSubject = new Subject<string[]>();
  readonly playerLobbyStatusChanged$ =
    this.playerLobbyStatusChangedSubject.asObservable();

  constructor(
    private readonly playersService: PlayersService,
    private readonly realtimeService: RealtimeService,
    private readonly matchmakingService: MatchmakingService,
    private readonly gameServersService: GameServersService,
  ) {}

  onModuleInit(): void {
    this.realtimeService.registerSnapshotProvider(
      ResourceName.Lobby,
      (playerId) => {
        const lobby = this.getLobbyForPlayer(playerId);
        if (!lobby) {
          throw new WsException('Lobby is not available');
        }
        return structuredClone(lobby);
      },
    );

    this.realtimeService.registerSnapshotProvider(
      ResourceName.LobbyInvites,
      (playerId) => this.getIncomingInvites(playerId),
    );

    this.realtimeService.registerBeforeAuthenticated((playerId) =>
      this.ensureLobby(playerId),
    );

    this.realtimeService.registerAfterAuthenticated((playerId) =>
      this.playerLobbyStatusChangedSubject.next([playerId]),
    );

    this.realtimeService.registerAfterDisconnected((playerId) =>
      this.cleanupPlayer(playerId),
    );

    this.matchmakingService.matchCreated$.subscribe({
      next: (lobbyIds) => {
        this.handleMatchCreated(lobbyIds);
      },
    });

    this.gameServersService.gameClosed$.subscribe({
      next: (playerIds) => {
        this.handleMatchClosed(playerIds);
      },
    });

    this.playersService.publicProfileChanged$.subscribe((playerId) => {
      void this.refreshLobbyPlayerTrophies(playerId).catch(console.error);
    });
  }

  invitePlayer(playerId: string, request: InvitePlayerRequestDto): void {
    const sourcePlayerLobby = this.getLobbyForPlayer(playerId);
    const invitedPlayerLobby = this.getLobbyForPlayer(request.invitedPlayerId);

    if (!sourcePlayerLobby || !invitedPlayerLobby) {
      throw new NotFoundException('Lobby not found');
    }

    if (
      sourcePlayerLobby.status !== 'open' ||
      invitedPlayerLobby.status !== 'open'
    ) {
      throw new BadRequestException('Lobby is not open');
    }

    if (sourcePlayerLobby.id === invitedPlayerLobby.id) {
      throw new BadRequestException('Player is already in this lobby');
    }

    const invitedPlayerInviteIds = this.inviteIdsByInvitedPlayerId.get(
      request.invitedPlayerId,
    );
    if (invitedPlayerInviteIds) {
      for (const inviteId of invitedPlayerInviteIds) {
        const invite = this.invites.get(inviteId);
        if (invite && invite.sourceLobbyId == sourcePlayerLobby.id) {
          throw new BadRequestException('Player is already invited');
        }
      }
    }

    const inviteId = randomUUID();
    this.addInvite({
      id: inviteId,
      sourceLobbyId: sourcePlayerLobby.id,
      sourcePlayerId: playerId,
      invitedPlayerId: request.invitedPlayerId,
    });

    this.publishInvites(new Set([request.invitedPlayerId]));
  }

  async acceptInvite(playerId: string, inviteId: string): Promise<void> {
    const invite = this.invites.get(inviteId);

    if (!invite || invite.invitedPlayerId !== playerId) {
      throw new NotFoundException('Invite not found');
    }

    const sourceLobby = this.lobbies.get(invite.sourceLobbyId);
    const previousLobby = this.getLobbyForPlayer(playerId);

    if (
      !sourceLobby ||
      sourceLobby.status !== 'open' ||
      sourceLobby.players.length >= MAX_LOBBY_PLAYERS
    ) {
      throw new BadRequestException('Lobby can not be joined');
    }

    const mode = MODES[sourceLobby.modeId];
    const maxPlayersForMode = mode.ranked
      ? mode.teamSize
      : mode.teamSize * mode.teamCount;
    if (sourceLobby.players.length >= maxPlayersForMode) {
      const fallbackModeId =
        DEFAULT_MODE_ID_BY_LOBBY_SIZE[sourceLobby.players.length + 1];
      if (!fallbackModeId) {
        throw new BadRequestException('No playable mode for this lobby size');
      }
      sourceLobby.modeId = fallbackModeId;
    }

    this.removePlayerFromLobby(playerId);
    await this.addPlayerToLobby(playerId, sourceLobby);

    const affectedRecipients = new Set<string>();
    this.deleteInvitesInvolvingSourcePlayer(playerId, affectedRecipients);
    this.deleteInvite(inviteId, affectedRecipients);

    for (const player of sourceLobby.players) {
      player.ready = false;
    }

    if (previousLobby) {
      this.publishLobby(previousLobby);
    }
    this.publishLobby(sourceLobby);
    this.publishInvites(affectedRecipients);
  }

  declineInvite(playerId: string, inviteId: string): void {
    const invite = this.invites.get(inviteId);

    if (!invite || invite.invitedPlayerId !== playerId) {
      throw new NotFoundException('Invite not found');
    }

    const affectedRecipients = new Set<string>();
    this.deleteInvite(inviteId, affectedRecipients);
    this.publishInvites(affectedRecipients);
  }

  async leaveLobby(playerId: string): Promise<void> {
    const lobby = this.getLobbyForPlayer(playerId);
    this.removePlayerFromLobby(playerId);
    if (lobby) {
      this.publishLobby(lobby);
    }

    const affectedRecipients = new Set<string>();
    this.deleteInvitesInvolvingSourcePlayer(playerId, affectedRecipients);
    this.publishInvites(affectedRecipients);

    await this.ensureLobby(playerId);
  }

  updateMode(playerId: string, request: UpdateModeRequestDto): void {
    const lobby = this.getLobbyForPlayer(playerId);

    if (!lobby) {
      throw new NotFoundException('Lobby not found');
    }

    if (lobby.status !== 'open') {
      throw new BadRequestException('Lobby is not open');
    }

    const mode = MODES[request.mode];

    const maxLobbyPlayers = mode.ranked
      ? mode.teamSize
      : mode.teamCount * mode.teamSize;

    if (lobby.players.length > maxLobbyPlayers) {
      throw new BadRequestException(
        'Mode is not playable with this lobby size',
      );
    }

    lobby.modeId = request.mode;

    for (const player of lobby.players) {
      player.ready = false;
    }

    this.publishLobby(lobby);
  }

  updateReady(playerId: string, request: UpdateReadyRequestDto): void {
    const lobby = this.getLobbyForPlayer(playerId);

    if (!lobby) {
      throw new NotFoundException('Lobby not found');
    }

    if (lobby.status !== 'open') {
      throw new BadRequestException('Lobby is not open');
    }

    const player = lobby.players.find((player) => player.id === playerId);

    if (!player) {
      throw new ForbiddenException('Player is not in this lobby');
    }

    player.ready = request.ready;

    if (lobby.players.every((player) => player.ready)) {
      lobby.status = 'matchmaking';

      this.playerLobbyStatusChangedSubject.next(
        lobby.players.map((member) => member.id),
      );

      this.matchmakingService.enqueue(
        lobby.id,
        lobby.modeId,
        lobby.players.map((player) => ({
          id: player.id,
          displayName: player.displayName,
          loadout: player.loadout,
        })),
      );
    }

    this.publishLobby(lobby);
  }

  async updateLoadout(
    playerId: string,
    request: UpdateLoadoutRequestDto,
  ): Promise<void> {
    const lobby = this.getLobbyForPlayer(playerId);

    if (!lobby) {
      throw new NotFoundException('Lobby not found');
    }

    if (lobby.status !== 'open') {
      throw new ConflictException('Lobby is not open');
    }

    const member = lobby.players.find((player) => player.id === playerId);

    if (!member) {
      throw new ForbiddenException('Player is not in this lobby');
    }

    member.loadout = await this.playersService.updateLoadout(playerId, request);

    this.publishLobby(lobby);
  }

  getPlayerLobbyStatus(playerId: string): Lobby['status'] | 'offline' {
    if (!this.realtimeService.isPlayerConnected(playerId)) {
      return 'offline';
    }
    return this.getLobbyForPlayer(playerId)?.status ?? 'offline';
  }

  private handleMatchCreated(lobbyIds: string[]): void {
    const affectedPlayers = new Set<string>();
    for (const lobbyId of lobbyIds) {
      const lobby = this.lobbies.get(lobbyId);
      if (!lobby) continue;

      lobby.status = 'in-game';
      this.publishLobby(lobby);

      for (const player of lobby.players) {
        affectedPlayers.add(player.id);
      }
    }
    if (affectedPlayers.size > 0) {
      this.playerLobbyStatusChangedSubject.next([...affectedPlayers]);
    }
  }

  private handleMatchClosed(playerIds: string[]): void {
    const affectedLobbyIds = new Set<string>();

    for (const playerId of playerIds) {
      const lobby = this.getLobbyForPlayer(playerId);

      if (lobby?.status === 'in-game') {
        affectedLobbyIds.add(lobby.id);
      }
    }

    for (const lobbyId of affectedLobbyIds) {
      const lobby = this.lobbies.get(lobbyId);
      if (!lobby) continue;

      lobby.status = 'open';

      lobby.players = lobby.players.filter((player) => {
        if (!this.realtimeService.isPlayerConnected(player.id)) {
          this.lobbyIdByPlayerId.delete(player.id);
          return false;
        }

        player.ready = false;
        return true;
      });

      if (lobby.players.length === 0) {
        this.lobbies.delete(lobby.id);
        continue;
      }

      this.publishLobby(lobby);
      this.playerLobbyStatusChangedSubject.next(
        lobby.players.map((player) => player.id),
      );
    }
  }

  private async ensureLobby(playerId: string): Promise<void> {
    if (this.getLobbyForPlayer(playerId)) return;

    const lobby: Lobby = {
      id: randomUUID(),
      modeId: DEFAULT_MODE_ID_BY_LOBBY_SIZE[1],
      players: [],
      status: 'open',
    };

    await this.addPlayerToLobby(playerId, lobby);
    this.lobbies.set(lobby.id, lobby);
    this.publishLobby(lobby);
  }

  private cleanupPlayer(playerId: string): void {
    const affectedRecipients = new Set<string>();
    this.deleteInvitesInvolvingSourcePlayer(playerId, affectedRecipients);
    this.deleteInvitesInvolvingInvitedPlayer(playerId, affectedRecipients);
    this.publishInvites(affectedRecipients);

    const lobby = this.getLobbyForPlayer(playerId);
    if (lobby?.status === 'open') {
      this.removePlayerFromLobby(playerId);
      this.publishLobby(lobby);
    }

    this.playerLobbyStatusChangedSubject.next([playerId]);
  }

  private async addPlayerToLobby(
    playerId: string,
    lobby: Lobby,
  ): Promise<void> {
    const player = await this.playersService.getPlayer(playerId);

    const lobbyPlayer: LobbyPlayer = {
      id: player.id,
      displayName: player.displayName,
      trophies: player.trophies,
      ready: false,
      loadout: { ...player.loadout },
    };

    lobby.players.push(lobbyPlayer);
    this.lobbyIdByPlayerId.set(playerId, lobby.id);
  }

  private removePlayerFromLobby(playerId: string): void {
    const lobby = this.getLobbyForPlayer(playerId);

    if (!lobby) {
      throw new NotFoundException('Lobby not found');
    }

    if (lobby.status !== 'open') {
      throw new BadRequestException('Lobby is not open');
    }

    lobby.players = lobby.players.filter((player) => player.id !== playerId);
    this.lobbyIdByPlayerId.delete(playerId);

    if (lobby.players.length === 0) {
      this.lobbies.delete(lobby.id);
      return;
    }

    for (const player of lobby.players) {
      player.ready = false;
    }
  }

  private addInvite(invite: LobbyInvite): void {
    let sourcePlayerInviteIds = this.inviteIdsBySourcePlayerId.get(
      invite.sourcePlayerId,
    );
    if (!sourcePlayerInviteIds) {
      sourcePlayerInviteIds = new Set<string>();
    }
    sourcePlayerInviteIds.add(invite.id);
    this.inviteIdsBySourcePlayerId.set(
      invite.sourcePlayerId,
      sourcePlayerInviteIds,
    );

    let invitedPlayerInviteIds = this.inviteIdsByInvitedPlayerId.get(
      invite.invitedPlayerId,
    );
    if (!invitedPlayerInviteIds) {
      invitedPlayerInviteIds = new Set<string>();
    }
    invitedPlayerInviteIds.add(invite.id);
    this.inviteIdsByInvitedPlayerId.set(
      invite.invitedPlayerId,
      invitedPlayerInviteIds,
    );

    this.invites.set(invite.id, invite);
  }

  private deleteInvite(
    inviteId: string,
    affectedRecipients: Set<string>,
  ): void {
    const invite = this.invites.get(inviteId);

    if (!invite) {
      return;
    }

    const sourcePlayerInviteIds = this.inviteIdsBySourcePlayerId.get(
      invite.sourcePlayerId,
    );
    if (sourcePlayerInviteIds) {
      sourcePlayerInviteIds.delete(inviteId);
      if (sourcePlayerInviteIds.size === 0) {
        this.inviteIdsBySourcePlayerId.delete(invite.sourcePlayerId);
      }
    }

    const invitedPlayerInviteIds = this.inviteIdsByInvitedPlayerId.get(
      invite.invitedPlayerId,
    );
    if (invitedPlayerInviteIds) {
      invitedPlayerInviteIds.delete(inviteId);
      if (invitedPlayerInviteIds.size === 0) {
        this.inviteIdsByInvitedPlayerId.delete(invite.invitedPlayerId);
      }
    }

    this.invites.delete(inviteId);
    affectedRecipients.add(invite.invitedPlayerId);
  }

  private deleteInvitesInvolvingSourcePlayer(
    sourcePlayerId: string,
    affectedRecipients: Set<string>,
  ): void {
    const sourcePlayerInviteIds =
      this.inviteIdsBySourcePlayerId.get(sourcePlayerId);
    if (sourcePlayerInviteIds) {
      for (const inviteId of [...sourcePlayerInviteIds]) {
        this.deleteInvite(inviteId, affectedRecipients);
      }
    }
  }

  private deleteInvitesInvolvingInvitedPlayer(
    invitedPlayerId: string,
    affectedRecipients: Set<string>,
  ): void {
    const invitedPlayerInviteIds =
      this.inviteIdsByInvitedPlayerId.get(invitedPlayerId);
    if (invitedPlayerInviteIds) {
      for (const inviteId of [...invitedPlayerInviteIds]) {
        this.deleteInvite(inviteId, affectedRecipients);
      }
    }
  }

  private getLobbyForPlayer(playerId: string): Lobby | undefined {
    const lobbyId = this.lobbyIdByPlayerId.get(playerId);

    if (!lobbyId) {
      return undefined;
    }

    return this.lobbies.get(lobbyId);
  }

  private getIncomingInvites(playerId: string): LobbyInviteSnapshot[] {
    const inviteIds = this.inviteIdsByInvitedPlayerId.get(playerId);
    if (!inviteIds) return [];

    return [...inviteIds].flatMap((inviteId) => {
      const invite = this.invites.get(inviteId);
      if (!invite) return [];

      const sourceLobby = this.lobbies.get(invite.sourceLobbyId);
      const sourcePlayer = sourceLobby?.players.find(
        (player) => player.id === invite.sourcePlayerId,
      );
      if (!sourcePlayer) return [];

      return [
        {
          inviteId: invite.id,
          sourcePlayer: {
            id: sourcePlayer.id,
            displayName: sourcePlayer.displayName,
            trophies: sourcePlayer.trophies,
          },
        },
      ];
    });
  }

  private async refreshLobbyPlayerTrophies(playerId: string): Promise<void> {
    const player = await this.playersService.getPlayer(playerId);

    const lobby = this.getLobbyForPlayer(playerId);
    const lobbyPlayer = lobby?.players.find((entry) => entry.id === playerId);

    if (!lobby || !lobbyPlayer) return;

    lobbyPlayer.trophies = player.trophies;
    this.publishLobby(lobby);

    const recipients = new Set<string>();

    for (const inviteId of this.inviteIdsBySourcePlayerId.get(playerId) ?? []) {
      const invite = this.invites.get(inviteId);
      if (invite) recipients.add(invite.invitedPlayerId);
    }

    this.publishInvites(recipients);
  }

  private publishLobby(lobby: Lobby): void {
    this.realtimeService.publishToPlayers(
      ResourceName.Lobby,
      lobby,
      lobby.players.map((player) => player.id),
    );
  }

  private publishInvites(playerIds: Set<string>): void {
    for (const playerId of playerIds) {
      this.realtimeService.publishToPlayers(
        ResourceName.LobbyInvites,
        this.getIncomingInvites(playerId),
        [playerId],
      );
    }
  }
}
