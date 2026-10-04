import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
<<<<<<< HEAD
import { ValidationPipe } from '@nestjs/common';
=======
>>>>>>> origin/main
import { WsAdapter } from '@nestjs/platform-ws';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
<<<<<<< HEAD

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  app.useWebSocketAdapter(new WsAdapter(app));

  await app.listen(3000);
=======
  app.enableCors();
  app.useWebSocketAdapter(new WsAdapter(app));
  await app.listen(8000, '0.0.0.0');
>>>>>>> origin/main
}
void bootstrap();
