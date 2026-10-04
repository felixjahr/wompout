FROM --platform=linux/amd64 ubuntu:24.04

WORKDIR /app

COPY server.x86_64 /app/server.x86_64
COPY server.pck /app/server.pck

RUN chmod +x /app/server.x86_64

ENTRYPOINT ["/app/server.x86_64"]