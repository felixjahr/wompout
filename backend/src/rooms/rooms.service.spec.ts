import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { RoomsGateway } from './rooms.gateway';
import { RoomsService } from './rooms.service';
import { PrismaService } from '../prisma.service';

describe('RoomsService', () => {
  let service: RoomsService;
  let roomsGateway: {
    onPlayerDisconnected: jest.Mock;
    hasPlayer: jest.Mock;
    sendRoomFailed: jest.Mock;
  };

  beforeEach(async () => {
    roomsGateway = {
      onPlayerDisconnected: jest.fn(),
      hasPlayer: jest.fn(() => true),
      sendRoomFailed: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        RoomsService,
        {
          provide: RoomsGateway,
          useValue: roomsGateway,
        },
        {
          provide: ConfigService,
          useValue: {
            get: jest.fn(),
          },
        },
        {
          provide: PrismaService,
          useValue: {
            player: {
              findMany: jest.fn(),
            },
          },
        },
      ],
    }).compile();

    service = module.get<RoomsService>(RoomsService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('removes a waiting room when its creator leaves', () => {
    const { code } = service.createRoom('player-1');

    service.leaveRoom(code, 'player-1');

    expect(service['rooms'].has(code)).toBe(false);
  });

  it('notifies remaining waiting room members when a player leaves', () => {
    const { code } = service.createRoom('player-1');
    service['rooms'].get(code)?.members.push('player-2');

    service.leaveRoom(code, 'player-1');

    expect(roomsGateway.sendRoomFailed).toHaveBeenCalledWith('player-2');
    expect(service['rooms'].has(code)).toBe(false);
  });
});
