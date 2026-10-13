import { PlayerLoadout } from '../players/players.types';

// Keep these pools in sync with the equipment registered in godot/data/data.gd.
export const BOT_LOADOUT_ITEMS = {
  rangedId: ['gun', 'rifle', 'bazooka', 'shotgun', 'smg', 'sniper'],
  meleeId: ['spear', 'sword', 'axe', 'hammer'],
  armourId: [
    'heavy_armour',
    'light_armour',
    'anti_knockback_armour',
    'spike_armour',
  ],
  abilityId: ['dash', 'invisibility', 'double_jump', 'slam_down'],
  styleId: ['red', 'blue', 'green', 'yellow', 'purple', 'cyan', 'orange', 'pink'],
} as const satisfies Record<keyof PlayerLoadout, readonly [string, ...string[]]>;

export function createRandomBotLoadout(): PlayerLoadout {
  const pick = (items: readonly string[]): string =>
    items[Math.floor(Math.random() * items.length)];

  return {
    rangedId: pick(BOT_LOADOUT_ITEMS.rangedId),
    meleeId: pick(BOT_LOADOUT_ITEMS.meleeId),
    armourId: pick(BOT_LOADOUT_ITEMS.armourId),
    abilityId: pick(BOT_LOADOUT_ITEMS.abilityId),
    styleId: pick(BOT_LOADOUT_ITEMS.styleId),
  };
}
