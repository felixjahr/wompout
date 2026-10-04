<<<<<<< HEAD
import { Controller, Get, Header } from '@nestjs/common';
=======
import { Controller, Get } from '@nestjs/common';
>>>>>>> origin/main
import { AppService } from './app.service';

@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

<<<<<<< HEAD
  @Get('.well-known/apple-app-site-association')
  @Header('Content-Type', 'application/json')
  appleAppSiteAssociation(): Record<string, unknown> {
    return this.appService.appleAppSiteAssociation();
  }

  @Get('.well-known/assetlinks.json')
  @Header('Content-Type', 'application/json')
  androidAssetLinks(): Record<string, unknown>[] {
    return this.appService.androidAssetLinks();
=======
  @Get()
  getHello(): string {
    return this.appService.getHello();
>>>>>>> origin/main
  }
}
