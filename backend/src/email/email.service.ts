import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Resend } from 'resend';

@Injectable()
export class EmailService {
  private readonly resend: Resend;

  constructor(private readonly config: ConfigService) {
    this.resend = new Resend(this.config.getOrThrow<string>('RESEND_API_KEY'));
  }

  async sendEmailVerificationCode(email: string, code: string) {
    await this.resend.emails.send({
      from: 'Wompout <auth@wompout.com>',
      to: email,
      subject: 'Your Wompout login code',
      text: `Your Wompout code is ${code}`,
    });
  }
}
