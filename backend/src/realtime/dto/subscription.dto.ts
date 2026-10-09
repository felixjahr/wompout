import {
  ArrayMaxSize,
  ArrayMinSize,
  ArrayUnique,
  IsArray,
  IsEnum,
} from 'class-validator';
import { ResourceName } from '../realtime.types';

export class SubscriptionDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(Object.values(ResourceName).length)
  @ArrayUnique()
  @IsEnum(ResourceName, { each: true })
  resources!: ResourceName[];
}
