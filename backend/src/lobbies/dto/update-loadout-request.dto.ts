import { IsNotEmpty, IsString, MaxLength } from 'class-validator';
import type { PlayerLoadout } from '../../players/players.types';

export class UpdateLoadoutRequestDto implements PlayerLoadout {
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  rangedId!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  meleeId!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  armourId!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  abilityId!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  styleId!: string;
}
