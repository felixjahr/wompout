import { IsBoolean } from 'class-validator';

export class UpdateReadyRequestDto {
  @IsBoolean()
  ready!: boolean;
}
