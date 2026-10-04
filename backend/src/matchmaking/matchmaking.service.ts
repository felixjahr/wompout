import { Injectable } from '@nestjs/common';
import { GameServersService } from '../game-servers/game-servers.service';
import { MAPS, MATCHMAKING_TIMEOUT_MS, MODES } from '../config/modes.config';
import {
  MatchmakingPlayer,
  MatchmakingTeam,
  MatchmakingTicket,
} from './matchmaking.types';
import { randomUUID } from 'node:crypto';
import { GameBot, GamePlayer } from '../game-servers/game-servers.types';
import { DEFAULT_LOADOUT } from '../config/default-player.config';
import { Subject } from 'rxjs';
import { BOT_NAMES } from '../config/bot-names.config';

@Injectable()
export class MatchmakingService {
  private readonly tickets = new Map<string, MatchmakingTicket>();
  private readonly ticketIdByLobbyId = new Map<string, string>();
  private readonly queuesByMode = new Map<keyof typeof MODES, string[]>();

  private readonly matchCreatedSubject = new Subject<string[]>();
  readonly matchCreated$ = this.matchCreatedSubject.asObservable();

  constructor(private readonly gameServersService: GameServersService) {}

  enqueue(
    lobbyId: string,
    modeId: keyof typeof MODES,
    players: MatchmakingPlayer[],
  ): void {
    this.cancelLobby(lobbyId);

    if (!MODES[modeId].ranked) {
      this.createPrivateGame(lobbyId, modeId, players);
      return;
    }
    const timeoutTimer = setTimeout(() => {
      this.createBotFillGame(ticket.id);
    }, MATCHMAKING_TIMEOUT_MS);

    const ticket: MatchmakingTicket = {
      id: randomUUID(),
      lobbyId,
      modeId,
      players,
      timeoutTimer,
    };

    this.tickets.set(ticket.id, ticket);
    this.ticketIdByLobbyId.set(lobbyId, ticket.id);

    let queue = this.queuesByMode.get(modeId);
    if (!queue) {
      queue = [];
      this.queuesByMode.set(modeId, queue);
    }
    queue.push(ticket.id);

    this.createPlayerOnlyGameIfPossible(modeId);
  }

  private createPlayerOnlyGameIfPossible(modeId: keyof typeof MODES): void {
    const mode = MODES[modeId];
    const tickets = this.getQueuedTickets(modeId);

    const teams: MatchmakingTeam[] = Array.from(
      { length: mode.teamCount },
      () => [],
    );
    const selectedTickets: MatchmakingTicket[] = [];

    const search = (ticketIndex: number): boolean => {
      if (teams.every((team) => team.length === mode.teamSize)) {
        return true;
      }

      if (ticketIndex >= tickets.length) {
        return false;
      }

      const ticket = tickets[ticketIndex];

      for (const team of teams) {
        if (team.length + ticket.players.length > MODES[modeId].teamSize) {
          continue;
        }

        team.push(...ticket.players);
        selectedTickets.push(ticket);

        if (search(ticketIndex + 1)) {
          return true;
        }

        selectedTickets.pop();
        team.splice(team.length - ticket.players.length, ticket.players.length);
      }

      return search(ticketIndex + 1);
    };

    if (!search(0)) {
      return;
    }

    this.createGame(
      modeId,
      selectedTickets,
      selectedTickets.map((ticket) => ticket.lobbyId),
      this.createGamePlayers(teams),
      [],
    );
  }

  private createBotFillGame(ticketId: string): void {
    const requiredTicket = this.tickets.get(ticketId);

    if (!requiredTicket) {
      return;
    }

    const modeId = requiredTicket.modeId;
    const mode = MODES[modeId];

    const teams: MatchmakingTeam[] = Array.from(
      { length: mode.teamCount },
      () => [],
    );
    const selectedTickets: MatchmakingTicket[] = [];

    this.placeTicketInFirstAvailableTeam(
      modeId,
      requiredTicket,
      teams,
      selectedTickets,
    );

    for (const ticket of this.getQueuedTickets(modeId)) {
      if (ticket.id === requiredTicket.id) {
        continue;
      }

      if (teams.every((team) => team.length === mode.teamSize)) {
        break;
      }

      this.placeTicketInFirstAvailableTeam(
        modeId,
        ticket,
        teams,
        selectedTickets,
      );
    }

    this.createGame(
      modeId,
      selectedTickets,
      selectedTickets.map((ticket) => ticket.lobbyId),
      this.createGamePlayers(teams),
      this.createGameBots(modeId, teams),
    );
  }

  private createPrivateGame(
    lobbyId: string,
    modeId: keyof typeof MODES,
    players: MatchmakingPlayer[],
  ): void {
    const mode = MODES[modeId];

    const teams: MatchmakingTeam[] = Array.from(
      { length: mode.teamCount },
      () => [],
    );

    for (const player of players) {
      const team = teams.find((team) => team.length < mode.teamSize);

      if (!team) {
        break;
      }

      team.push(player);
    }

    this.createGame(
      modeId,
      [],
      [lobbyId],
      this.createGamePlayers(teams),
      this.createGameBots(modeId, teams),
    );
  }

  private createGame(
    modeId: keyof typeof MODES,
    tickets: MatchmakingTicket[],
    lobbIds: string[],
    players: GamePlayer[],
    bots: GameBot[],
  ): void {
    for (const ticket of tickets) {
      this.removeTicket(ticket.id);
    }

    this.gameServersService.startGame({
      id: randomUUID(),
      modeId,
      mapId: MAPS[Math.floor(Math.random() * MAPS.length)],
      players,
      bots,
    });

    this.matchCreatedSubject.next(lobbIds);
  }

  private createGamePlayers(teams: MatchmakingTeam[]): GamePlayer[] {
    return teams.flatMap((team, teamId) =>
      team.map((player) => ({
        id: player.id,
        displayName: player.displayName,
        teamId,
        loadout: player.loadout,
      })),
    );
  }

  private createGameBots(
    modeId: keyof typeof MODES,
    teams: MatchmakingTeam[],
  ): GameBot[] {
    const bots: GameBot[] = [];
    const mode = MODES[modeId];

    for (let teamId = 0; teamId < mode.teamCount; teamId++) {
      const missingBotCount = mode.teamSize - teams[teamId].length;

      for (let i = 0; i < missingBotCount; i++) {
        bots.push({
          id: randomUUID(),
          displayName: BOT_NAMES[Math.floor(Math.random() * BOT_NAMES.length)],
          teamId,
          loadout: DEFAULT_LOADOUT,
        });
      }
    }

    return bots;
  }

  private placeTicketInFirstAvailableTeam(
    modeId: keyof typeof MODES,
    ticket: MatchmakingTicket,
    teams: MatchmakingTeam[],
    selectedTickets: MatchmakingTicket[],
  ): boolean {
    const team = teams.find(
      (team) => team.length + ticket.players.length <= MODES[modeId].teamSize,
    );

    if (!team) {
      return false;
    }

    team.push(...ticket.players);
    selectedTickets.push(ticket);
    return true;
  }

  private getQueuedTickets(modeId: keyof typeof MODES): MatchmakingTicket[] {
    return (this.queuesByMode.get(modeId) ?? [])
      .map((ticketId) => this.tickets.get(ticketId))
      .filter((ticket): ticket is MatchmakingTicket => !!ticket);
  }

  private cancelLobby(lobbyId: string): void {
    const ticketId = this.ticketIdByLobbyId.get(lobbyId);
    if (!ticketId) return;

    this.removeTicket(ticketId);
  }

  private removeTicket(ticketId: string): void {
    const ticket = this.tickets.get(ticketId);
    if (!ticket) return;

    clearTimeout(ticket.timeoutTimer);

    this.tickets.delete(ticket.id);
    this.ticketIdByLobbyId.delete(ticket.lobbyId);

    const queue = this.queuesByMode.get(ticket.modeId) ?? [];
    this.queuesByMode.set(
      ticket.modeId,
      queue.filter((id) => id !== ticket.id),
    );
  }
}
