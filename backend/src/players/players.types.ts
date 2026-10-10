export interface Player {
  id: string;
  displayName: string;
  email: string | null;
  trophies: number;
  highestTrophies: number;
  coins: number;
  gems: number;
  chestProgress: {
    progress: number;
    requiredProgress: number;
    readyChests: number;
    dailyBonusWinsRemaining: number;
    nextDailyBonusAt: string | null;
  };
  loadout: PlayerLoadout;
  items: {
    itemId: string;
    unlockedAt: string;
  }[];
}

export interface PlayerLoadout {
  rangedId: string;
  meleeId: string;
  armourId: string;
  abilityId: string;
  styleId: string;
}

export type ChestContent =
  | { type: 'coins'; amount: number }
  | { type: 'gems'; amount: number }
  | { type: 'item'; itemId: string };
