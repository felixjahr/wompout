import { IsEmail, IsString } from 'class-validator';
import { Transform } from 'class-transformer';

export class EmailRequestDto {
  @Transform(({ value }) => {
    const input: unknown = value;
    return typeof input === 'string' ? input.trim().toLowerCase() : input;
  })
  @IsString()
  @IsEmail()
  email!: string;
}
