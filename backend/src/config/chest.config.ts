export const INTRO_CHEST_REQUIREMENTS = [1, 2, 2, 3, 3] as const;
export const REGULAR_CHEST_REQUIREMENT = 4;

export type CurrencyRollConfig = {
  min: number;
  max: number;
  k: number;
};

type ChestRewardsConfig = {
  coins: { weight: number; amount: CurrencyRollConfig };
  gems: { weight: number; amount: CurrencyRollConfig };
  items: { weight: number };
};

export const CHEST_REWARDS: ChestRewardsConfig = {
  coins: {
    weight: 30,
    amount: { min: 500, max: 10000, k: 3 },
  },
  gems: {
    weight: 30,
    amount: { min: 5, max: 100, k: 3 },
  },
  items: {
    weight: 40,
  },
};

export type ChestItemGroup = {
  weight: number;
  items: string[];
};

export const CHEST_ITEM_GROUPS: ChestItemGroup[] = [
  {
    weight: 55,
    items: [
      'gun',
      'sword',
      'light_armour',
      'dash',
      'rifle',
      'spear',
      'heavy_armour',
      'double_jump',
      'red',
      'blue',
      'green',
    ],
  },
  {
    weight: 30,
    items: [
      'shotgun',
      'smg',
      'axe',
      'anti_knockback_armour',
      'invisibility',
      'yellow',
      'orange',
      'cyan',
    ],
  },
  {
    weight: 15,
    items: [
      'bazooka',
      'sniper',
      'hammer',
      'spike_armour',
      'slam_down',
      'pink',
      'purple',
    ],
  },
];
