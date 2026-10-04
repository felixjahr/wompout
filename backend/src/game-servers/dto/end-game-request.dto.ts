import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  ArrayUnique,
  IsArray,
  IsDefined,
  IsInt,
  IsNotEmpty,
  IsString,
  IsUUID,
  Min,
  ValidateNested,
} from 'class-validator';

export class MatchLoadoutDto {
  @IsString()
  @IsNotEmpty()
  rangedId!: string;

  @IsString()
  @IsNotEmpty()
  meleeId!: string;

  @IsString()
  @IsNotEmpty()
  armourId!: string;

  @IsString()
  @IsNotEmpty()
  abilityId!: string;
}

export class ParticipantResultDto {
  @IsUUID()
  participantId!: string;

  @IsInt()
  @Min(1)
  placement!: number;

  @IsDefined()
  @Type(() => MatchLoadoutDto)
  @ValidateNested()
  loadout!: MatchLoadoutDto;
}

export class EndGameRequestDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayUnique((result: ParticipantResultDto) => result?.participantId)
  @Type(() => ParticipantResultDto)
  @ValidateNested({ each: true })
  results!: ParticipantResultDto[];
}
