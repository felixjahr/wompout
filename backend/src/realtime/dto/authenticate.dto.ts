import { IsString, MaxLength, MinLength } from 'class-validator';

export class AuthenticateDto {
  @IsString()
  @MinLength(1)
  @MaxLength(8192)
  accessToken!: string;
}
