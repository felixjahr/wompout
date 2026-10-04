export const DEFAULT_LOADOUT = {
  rangedId: 'gun',
  meleeId: 'sword',
  armourId: 'light_armour',
  abilityId: 'dash',
} as const;

export const DEFAULT_ITEMS = [
  { itemType: 'RANGED', itemId: 'gun' },
  { itemType: 'MELEE', itemId: 'sword' },
  { itemType: 'ARMOUR', itemId: 'light_armour' },
  { itemType: 'ABILITY', itemId: 'dash' },
] as const;
