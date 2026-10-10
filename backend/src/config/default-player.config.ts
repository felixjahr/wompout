export const DEFAULT_LOADOUT = {
  rangedId: 'gun',
  meleeId: 'sword',
  armourId: 'light_armour',
  abilityId: 'dash',
  styleId: 'red',
} as const;

export const DEFAULT_ITEMS = [
  { itemId: 'gun' },
  { itemId: 'sword' },
  { itemId: 'light_armour' },
  { itemId: 'dash' },
  { itemId: 'red' },
] as const;
