import { INestApplication, UnauthorizedException } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import request from 'supertest';
import type { Server } from 'node:http';
import { PlayersController } from './players.controller';
import { PlayersService } from './players.service';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeService } from '../realtime/realtime.service';
import { SessionsService } from '../sessions/sessions.service';
import { SessionsGuard } from '../sessions/sessions.guard';

// Exercise real routing, guard, session validation, and deletion orchestration.
// Database cascades are defined in schema.prisma; persistence is mocked here.
describe('POST /players/delete', () => {
  let app: INestApplication;
  const tx = {
    player: {
      findUnique: jest.fn(),
      deleteMany: jest.fn(),
    },
    friendship: { findMany: jest.fn() },
    playerProgression: { findUnique: jest.fn(), update: jest.fn() },
    signupVerificationCode: { deleteMany: jest.fn() },
  };
  const prisma = {
    $transaction: jest.fn(),
    session: { findFirst: jest.fn() },
  };
  const jwt = { verifyAsync: jest.fn() };
  const realtime = {
    disconnectPlayer: jest.fn(),
    registerSnapshotProvider: jest.fn(),
  };

  beforeAll(async () => {
    const module = await Test.createTestingModule({
      controllers: [PlayersController],
      providers: [
        PlayersService,
        SessionsService,
        SessionsGuard,
        { provide: PrismaService, useValue: prisma },
        { provide: RealtimeService, useValue: realtime },
        { provide: JwtService, useValue: jwt },
        { provide: ConfigService, useValue: {} },
      ],
    }).compile();
    app = module.createNestApplication();
    await app.init();
  });

  beforeEach(() => {
    jest.resetAllMocks();
    jwt.verifyAsync.mockResolvedValue({
      sub: 'self',
      sid: 'session',
      exp: Date.now() / 1000 + 300,
    });
    prisma.session.findFirst.mockResolvedValue({ id: 'session' });
    prisma.$transaction.mockImplementation(
      (operation: (client: typeof tx) => unknown) => operation(tx),
    );
    tx.player.findUnique.mockResolvedValue({ email: 'self@example.com' });
    tx.player.deleteMany.mockResolvedValue({ count: 1 });
    tx.friendship.findMany.mockResolvedValue([
      { playerAId: 'self', playerBId: 'friend' },
    ]);
    tx.signupVerificationCode.deleteMany.mockResolvedValue({ count: 1 });
  });

  afterAll(async () => {
    await app.close();
  });

  it('requires a bearer token before deleting anything', async () => {
    await request(app.getHttpServer() as Server)
      .post('/players/delete')
      .expect(401);
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('rejects invalid tokens and deleted or revoked sessions', async () => {
    jwt.verifyAsync.mockRejectedValueOnce(new UnauthorizedException());
    await request(app.getHttpServer() as Server)
      .post('/players/delete')
      .auth('invalid', { type: 'bearer' })
      .expect(401);
    prisma.session.findFirst.mockResolvedValue(null);
    await request(app.getHttpServer() as Server)
      .post('/players/delete')
      .auth('deleted', { type: 'bearer' })
      .expect(401);
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('deletes only the authenticated account and returns an empty 204', async () => {
    const deleted = jest.fn();
    const subscription = app
      .get(PlayersService)
      .accountDeleted$.subscribe(deleted);
    const response = await request(app.getHttpServer() as Server)
      .post('/players/delete')
      .auth('valid', { type: 'bearer' })
      .send({ playerId: 'someone-else' })
      .expect(204);
    expect(response.text).toBe('');
    expect(tx.player.deleteMany).toHaveBeenCalledWith({
      where: { id: 'self' },
    });
    expect(tx.signupVerificationCode.deleteMany).toHaveBeenCalledWith({
      where: { email: 'self@example.com' },
    });
    expect(realtime.disconnectPlayer).toHaveBeenCalledWith('self');
    expect(deleted).toHaveBeenCalledWith({
      playerId: 'self',
      friendIds: ['friend'],
    });
    expect(prisma.session.findFirst).toHaveBeenCalledWith({
      where: {
        id: 'session',
        playerId: 'self',
        revokedAt: null,
        expiresAt: { gt: expect.any(Date) as Date },
      },
      select: { id: true },
    });
    subscription.unsubscribe();
  });

  it('supports guest accounts without deleting unrelated signup codes', async () => {
    tx.player.findUnique.mockResolvedValue({ email: null });
    await request(app.getHttpServer() as Server)
      .post('/players/delete')
      .auth('valid', { type: 'bearer' })
      .expect(204);
    expect(tx.signupVerificationCode.deleteMany).not.toHaveBeenCalled();
    expect(tx.player.deleteMany).toHaveBeenCalled();
  });

  it('ignores late match results for deleted accounts', async () => {
    tx.playerProgression.findUnique.mockResolvedValue(null);
    await expect(
      app.get(PlayersService).recordMatchResult('self', 10),
    ).resolves.toBe(0);
    expect(tx.playerProgression.update).not.toHaveBeenCalled();
  });

  it('does not disconnect or emit deletion events if the transaction fails', async () => {
    const failure = new Error('Database unavailable');
    prisma.$transaction.mockRejectedValue(failure);
    const deleted = jest.fn();
    const subscription = app
      .get(PlayersService)
      .accountDeleted$.subscribe(deleted);
    await expect(app.get(PlayersService).deleteAccount('self')).rejects.toThrow(
      failure,
    );
    expect(realtime.disconnectPlayer).not.toHaveBeenCalled();
    expect(deleted).not.toHaveBeenCalled();
    subscription.unsubscribe();
  });
});
