export interface Player {
  id: string;
  displayName: string;
  email: string | null;
  trophies: number;
  highestTrophies: number;
  loadout: {
    rangedId: string;
    meleeId: string;
    armourId: string;
    abilityId: string;
  };
  items: {
    itemType: string;
    itemId: string;
    unlockedAt: string;
  }[];
}
