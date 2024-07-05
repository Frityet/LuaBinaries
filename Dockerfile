FROM alpine:latest

RUN apk add --no-cache lua5.4 lua5.4-dev luarocks5.4

WORKDIR /app
COPY . .

RUN luarocks init
RUN luarocks make

RUN ./dump-modules.lua get-lua 5.4.7 -o 5.4.7

RUN ./compile.lua

CMD [ "out/main" "get-lua", "LuaJIT" "-o", "LuaJIT" ]
