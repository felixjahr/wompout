import { IsEmail, IsString, Length } from 'class-validator';
import { Transform } from 'class-transformer';

export class StartSignupRequestDto {
  @Transform(({ value }) => {
    const input: unknown = value;
    return typeof input === 'string' ? input.trim() : input;
  })
  @IsString()
  @Length(1, 16)
  displayName!: string;

  @Transform(({ value }) => {
    const input: unknown = value;
    return typeof input === 'string' ? input.trim().toLowerCase() : input;
  })
  @IsString()
  @IsEmail()
  email!: string;
}
