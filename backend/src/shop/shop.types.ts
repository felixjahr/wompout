import type { ShopOffer } from '../config/shop.config';

export interface Shop {
  offers: readonly ShopOffer[];
}
