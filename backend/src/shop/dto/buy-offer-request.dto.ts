import { IsNotEmpty, IsString } from 'class-validator';

export class BuyOfferRequestDto {
  @IsString()
  @IsNotEmpty()
  offerId!: string;
}
