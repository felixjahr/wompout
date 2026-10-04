import { IsIn } from 'class-validator';
import { MODES } from '../../config/modes.config';

export class UpdateModeRequestDto {
  @IsIn(Object.keys(MODES))
  mode!: keyof typeof MODES;
}
