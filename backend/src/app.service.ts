import { Injectable } from '@nestjs/common';
<<<<<<< HEAD
import { ConfigService } from '@nestjs/config';

@Injectable()
export class AppService {
  constructor(private readonly configService: ConfigService) {}

  appleAppSiteAssociation(): Record<string, unknown> {
    const appIdPrefix =
      this.configService.getOrThrow<string>('IOS_APP_ID_PREFIX');
    const bundleId = this.configService.getOrThrow<string>('IOS_BUNDLE_ID');

    return {
      applinks: {
        apps: [],
        details: [
          {
            appID: `${appIdPrefix}.${bundleId}`,
            paths: ['/friends/invite/*'],
          },
        ],
      },
    };
  }

  androidAssetLinks(): Record<string, unknown>[] {
    return [
      {
        relation: ['delegate_permission/common.handle_all_urls'],
        target: {
          namespace: 'android_app',
          package_name: this.configService.getOrThrow<string>(
            'ANDROID_PACKAGE_NAME',
          ),
          sha256_cert_fingerprints: [
            this.configService.getOrThrow<string>(
              'ANDROID_SHA256_CERT_FINGERPRINT',
            ),
          ],
        },
      },
    ];
=======

@Injectable()
export class AppService {
  getHello(): string {
    return 'Hello World!';
>>>>>>> origin/main
  }
}
