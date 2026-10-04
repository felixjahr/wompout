import { IsUUID } from 'class-validator';

export class InvitePlayerRequestDto {
  @IsUUID()
  invitedPlayerId!: string;
}
