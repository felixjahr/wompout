import { Injectable, NotFoundException, OnModuleInit } from '@nestjs/common';
import { SHOP_OFFERS } from '../config/shop.config';
import { RealtimeService } from '../realtime/realtime.service';
import { ResourceName } from '../realtime/realtime.types';
import { Shop } from './shop.types';
import { PlayersService } from '../players/players.service';
import { BuyOfferRequestDto } from './dto/buy-offer-request.dto';

@Injectable()
export class ShopService implements OnModuleInit {
  constructor(
    private readonly realtimeService: RealtimeService,
    private readonly playersService: PlayersService,
  ) {}

  onModuleInit(): void {
    this.realtimeService.registerSnapshotProvider(ResourceName.Shop, () =>
      this.getShop(),
    );
  }

  async buyOffer(playerId: string, request: BuyOfferRequestDto): Promise<void> {
    const offer = SHOP_OFFERS.find(
      (offer) => offer.offerId === request.offerId,
    );
    if (!offer) {
      throw new NotFoundException('Shop offer not found');
    }

    await this.playersService.unlockItem(playerId, offer.itemId, offer.price);
  }

  private getShop(): Shop {
    return { offers: SHOP_OFFERS };
  }
}
