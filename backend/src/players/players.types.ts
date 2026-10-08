export interface Player {
  id: string;
  displayName: string;
  email: string | null;
  trophies: number;
  highestTrophies: number;
  loadout: PlayerLoadout;
  items: {
    itemType: string;
    itemId: string;
    unlockedAt: string;
  }[];
}

export interface PlayerLoadout {
  rangedId: string;
  meleeId: string;
  armourId: string;
  abilityId: string;
}
