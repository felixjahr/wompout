import { Injectable, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { Resend } from 'resend';

@Injectable()
export class EmailService {
  private readonly resend: Resend;

  private readonly verificationTemplate = readFileSync(
    join(__dirname, 'templates', 'verification-code.html'),
    'utf8',
  );

  constructor(private readonly config: ConfigService) {
    this.resend = new Resend(this.config.getOrThrow<string>('RESEND_API_KEY'));
  }

  async sendEmailVerificationCode(email: string, code: string) {
    const escapes: Record<string, string> = {
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      "'": '&#39;',
    };
    const safeCode = code.replace(
      /[&<>"']/g,
      (character) => escapes[character],
    );
    const { error } = await this.resend.emails.send({
      from: 'Wompout <auth@wompout.com>',
      to: email,
      subject: 'Your Wompout verification code',
      text: `Your Wompout verification code is ${code}`,
      html: this.verificationTemplate.replace('{{CODE}}', () => safeCode),
    });

    if (error) {
      throw new ServiceUnavailableException(
        'Unable to send verification email',
      );
    }
  }
}
