FROM barichello/godot-ci:4.7.2 AS export

WORKDIR /godot

COPY . .

RUN mkdir -p /export
RUN godot --headless --path /godot --export-release "Game Server" "/export/game-server.x86_64"

FROM debian:bookworm-slim

WORKDIR /app

COPY --from=export /export/ ./

RUN chmod +x /app/game-server.x86_64

ENTRYPOINT ["/app/game-server.x86_64"]