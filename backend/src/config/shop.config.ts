export type ShopCurrency = 'coins' | 'gems';

export interface ShopOffer {
  readonly offerId: string;
  readonly itemId: string;
  readonly price: {
    readonly currency: ShopCurrency;
    readonly amount: number;
  };
}

export const SHOP_OFFERS: readonly ShopOffer[] = [
  {
    offerId: 'offer_gun',
    itemId: 'gun',
    price: { currency: 'coins', amount: 3000 },
  },
  {
    offerId: 'offer_rifle',
    itemId: 'rifle',
    price: { currency: 'coins', amount: 4500 },
  },
  {
    offerId: 'offer_shotgun',
    itemId: 'shotgun',
    price: { currency: 'coins', amount: 6500 },
  },
  {
    offerId: 'offer_smg',
    itemId: 'smg',
    price: { currency: 'gems', amount: 65 },
  },
  {
    offerId: 'offer_bazooka',
    itemId: 'bazooka',
    price: { currency: 'gems', amount: 100 },
  },
  {
    offerId: 'offer_sniper',
    itemId: 'sniper',
    price: { currency: 'coins', amount: 10000 },
  },
  {
    offerId: 'offer_sword',
    itemId: 'sword',
    price: { currency: 'coins', amount: 3000 },
  },
  {
    offerId: 'offer_spear',
    itemId: 'spear',
    price: { currency: 'coins', amount: 4500 },
  },
  {
    offerId: 'offer_axe',
    itemId: 'axe',
    price: { currency: 'gems', amount: 60 },
  },
  {
    offerId: 'offer_hammer',
    itemId: 'hammer',
    price: { currency: 'coins', amount: 9000 },
  },
  // Armour
  {
    offerId: 'offer_light_armour',
    itemId: 'light_armour',
    price: { currency: 'coins', amount: 3000 },
  },
  {
    offerId: 'offer_heavy_armour',
    itemId: 'heavy_armour',
    price: { currency: 'coins', amount: 5000 },
  },
  {
    offerId: 'offer_anti_knockback_armour',
    itemId: 'anti_knockback_armour',
    price: { currency: 'gems', amount: 70 },
  },
  {
    offerId: 'offer_spike_armour',
    itemId: 'spike_armour',
    price: { currency: 'gems', amount: 90 },
  },
  {
    offerId: 'offer_dash',
    itemId: 'dash',
    price: { currency: 'coins', amount: 3000 },
  },
  {
    offerId: 'offer_double_jump',
    itemId: 'double_jump',
    price: { currency: 'coins', amount: 5000 },
  },
  {
    offerId: 'offer_invisibility',
    itemId: 'invisibility',
    price: { currency: 'gems', amount: 75 },
  },
  {
    offerId: 'offer_slam_down',
    itemId: 'slam_down',
    price: { currency: 'coins', amount: 9500 },
  },
  {
    offerId: 'offer_red',
    itemId: 'red',
    price: { currency: 'coins', amount: 3000 },
  },
  {
    offerId: 'offer_blue',
    itemId: 'blue',
    price: { currency: 'gems', amount: 30 },
  },
  {
    offerId: 'offer_green',
    itemId: 'green',
    price: { currency: 'coins', amount: 3500 },
  },
  {
    offerId: 'offer_yellow',
    itemId: 'yellow',
    price: { currency: 'coins', amount: 4500 },
  },
  {
    offerId: 'offer_orange',
    itemId: 'orange',
    price: { currency: 'gems', amount: 45 },
  },
  {
    offerId: 'offer_cyan',
    itemId: 'cyan',
    price: { currency: 'coins', amount: 5000 },
  },
  {
    offerId: 'offer_pink',
    itemId: 'pink',
    price: { currency: 'gems', amount: 60 },
  },
  {
    offerId: 'offer_purple',
    itemId: 'purple',
    price: { currency: 'gems', amount: 70 },
  },
];
