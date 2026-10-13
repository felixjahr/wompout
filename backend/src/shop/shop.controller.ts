import {
  Body,
  Controller,
  HttpCode,
  HttpStatus,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ShopService } from './shop.service';
import { SessionsGuard } from '../sessions/sessions.guard';
import { PlayerId } from '../sessions/decorators/player-id.decorator';
import { BuyOfferRequestDto } from './dto/buy-offer-request.dto';

@Controller('shop')
@UseGuards(SessionsGuard)
export class ShopController {
  constructor(private readonly shopService: ShopService) {}

  @Post('buy')
  @HttpCode(HttpStatus.NO_CONTENT)
  buyOffer(
    @PlayerId() playerId: string,
    @Body() request: BuyOfferRequestDto,
  ): Promise<void> {
    return this.shopService.buyOffer(playerId, request);
  }
}
