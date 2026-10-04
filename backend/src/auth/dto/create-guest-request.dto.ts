import { IsString, Length } from 'class-validator';
import { Transform } from 'class-transformer';

export class CreateGuestRequestDto {
  @Transform(({ value }) => {
    const input: unknown = value;
    return typeof input === 'string' ? input.trim() : input;
  })
  @IsString()
  @Length(1, 16)
  displayName!: string;
}
