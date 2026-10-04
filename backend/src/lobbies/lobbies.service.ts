import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  OnModuleInit,
} from '@nestjs/common';
import { Lobby, LobbyInvite, LobbyPlayer } from './lobbies.types';
import { PrismaService } from '../prisma/prisma.service';
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
  private readonly invitesChangedSubject = new Subject<string[]>();
  readonly invitesChanged$ = this.invitesChangedSubject.asObservable();

  constructor(
    private readonly prismaService: PrismaService,
    private readonly realtimeService: RealtimeService,
    private readonly matchmakingService: MatchmakingService,
    private readonly gameServersService: GameServersService,
  ) {}

  onModuleInit(): void {
    this.realtimeService.connected$.subscribe({
      next: (playerId) => {
        void this.handlePlayerConnected(playerId).catch(console.error);
      },
    });

    this.realtimeService.disconnected$.subscribe({
      next: (playerId) => {
        this.handlePlayerDisconnected(playerId);
      },
    });

    this.matchmakingService.matchCreated$.subscribe({
      next: (lobbyIds) => {
        this.handleMatchCreated(lobbyIds);
      },
    });

    this.gameServersService.gameClosed$.subscribe({
      next: (playerIds) => {
        this.handleGameClosed(playerIds);
      },
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

    this.invitesChangedSubject.next([request.invitedPlayerId]);
  }

  async acceptInvite(playerId: string, inviteId: string): Promise<void> {
    const invite = this.invites.get(inviteId);

    if (!invite || invite.invitedPlayerId !== playerId) {
      throw new NotFoundException('Invite not found');
    }

    const sourceLobby = this.lobbies.get(invite.sourceLobbyId);

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

    this.sendLobbyToPlayers(sourceLobby);
    this.notifyInvitesChanged(affectedRecipients);
  }

  declineInvite(playerId: string, inviteId: string): void {
    const invite = this.invites.get(inviteId);

    if (!invite || invite.invitedPlayerId !== playerId) {
      throw new NotFoundException('Invite not found');
    }

    const affectedRecipients = new Set<string>();
    this.deleteInvite(inviteId, affectedRecipients);
    this.notifyInvitesChanged(affectedRecipients);
  }

  async leaveLobby(playerId: string): Promise<void> {
    this.removePlayerFromLobby(playerId);
    await this.createLobby(playerId);

    const affectedRecipients = new Set<string>();
    this.deleteInvitesInvolvingSourcePlayer(playerId, affectedRecipients);
    this.notifyInvitesChanged(affectedRecipients);
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

    this.sendLobbyToPlayers(lobby);
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

    this.sendLobbyToPlayers(lobby);
  }

  async handlePlayerConnected(playerId: string): Promise<void> {
    const lobby = this.getLobbyForPlayer(playerId);

    if (!lobby) {
      await this.createLobby(playerId);
      return;
    }

    if (lobby.status === 'open') {
      this.removePlayerFromLobby(playerId);
      await this.createLobby(playerId);
      return;
    }

    this.sendLobbyToPlayer(playerId, lobby);
    this.playerLobbyStatusChangedSubject.next([playerId]);
    this.gameServersService.sendActiveGameToPlayer(playerId);
  }

  handlePlayerDisconnected(playerId: string): void {
    const affectedRecipients = new Set<string>();
    this.deleteInvitesInvolvingSourcePlayer(playerId, affectedRecipients);
    this.deleteInvitesInvolvingInvitedPlayer(playerId, affectedRecipients);

    const lobby = this.getLobbyForPlayer(playerId);

    if (lobby?.status === 'open') {
      this.removePlayerFromLobby(playerId);
    }

    this.notifyInvitesChanged(affectedRecipients);
    this.playerLobbyStatusChangedSubject.next([playerId]);
  }

  getPlayerLobbyStatus(playerId: string): Lobby['status'] | 'offline' {
    if (!this.realtimeService.isPlayerConnected(playerId)) {
      return 'offline';
    }
    return this.getLobbyForPlayer(playerId)?.status ?? 'offline';
  }

  getIncomingInvites(playerId: string): {
    inviteId: string;
    sourcePlayerId: string;
    sourceDisplayName: string;
  }[] {
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
          sourcePlayerId: invite.sourcePlayerId,
          sourceDisplayName: sourcePlayer.displayName,
        },
      ];
    });
  }

  private handleMatchCreated(lobbyIds: string[]): void {
    const affectedPlayers = new Set<string>();
    for (const lobbyId of lobbyIds) {
      const lobby = this.lobbies.get(lobbyId);
      if (!lobby) continue;

      lobby.status = 'in-game';
      this.sendLobbyToPlayers(lobby);

      for (const player of lobby.players) {
        affectedPlayers.add(player.id);
      }
    }
    if (affectedPlayers.size > 0) {
      this.playerLobbyStatusChangedSubject.next([...affectedPlayers]);
    }
  }

  private handleGameClosed(playerIds: string[]): void {
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

      this.sendLobbyToPlayers(lobby);
      this.playerLobbyStatusChangedSubject.next(
        lobby.players.map((player) => player.id),
      );
    }
  }

  private async createLobby(playerId: string): Promise<void> {
    const lobby: Lobby = {
      id: randomUUID(),
      modeId: DEFAULT_MODE_ID_BY_LOBBY_SIZE[1],
      players: [],
      status: 'open',
    };

    await this.addPlayerToLobby(playerId, lobby);

    this.lobbies.set(lobby.id, lobby);
    this.sendLobbyToPlayers(lobby);
    this.playerLobbyStatusChangedSubject.next([playerId]);
  }

  private async addPlayerToLobby(
    playerId: string,
    lobby: Lobby,
  ): Promise<void> {
    const player = await this.prismaService.player.findUnique({
      where: {
        id: playerId,
      },
      include: {
        loadout: true,
      },
    });

    if (!player || !player.loadout) {
      throw new NotFoundException('Player or loadout not found');
    }

    const lobbyPlayer: LobbyPlayer = {
      id: player.id,
      displayName: player.displayName,
      ready: false,
      loadout: {
        rangedId: player.loadout.rangedId,
        meleeId: player.loadout.meleeId,
        armourId: player.loadout.armourId,
        abilityId: player.loadout.abilityId,
      },
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

    this.sendLobbyToPlayers(lobby);
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

  private notifyInvitesChanged(affectedRecipients: Set<string>): void {
    if (affectedRecipients.size === 0) return;

    this.invitesChangedSubject.next([...affectedRecipients]);
  }

  private getLobbyForPlayer(playerId: string): Lobby | undefined {
    const lobbyId = this.lobbyIdByPlayerId.get(playerId);

    if (!lobbyId) {
      return undefined;
    }

    return this.lobbies.get(lobbyId);
  }

  private sendLobbyToPlayers(lobby: Lobby): void {
    for (const player of lobby.players) {
      this.sendLobbyToPlayer(player.id, lobby);
    }
  }

  private sendLobbyToPlayer(playerId: string, lobby: Lobby): void {
    this.realtimeService.sendToPlayer(playerId, 'lobbyUpdated', { lobby });
  }
}
