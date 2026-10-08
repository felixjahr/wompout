import {
  ArrayMaxSize,
  ArrayMinSize,
  ArrayUnique,
  IsArray,
  IsEnum,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';
import { ResourceName } from '../realtime.types';

export class SubscriptionDto {
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  requestId!: string;

  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(Object.values(ResourceName).length)
  @ArrayUnique()
  @IsEnum(ResourceName, { each: true })
  resources!: ResourceName[];
}
