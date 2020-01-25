project := 'httoolsp'

cwd := invocation_directory()

export LUA_PATH := cwd + '/src/?.lua;' + cwd + '/src/?/init.lua;'

_list:
  @just --list

install-dev-deps:
  luarocks install moonscript
  luarocks install moonpick
  luarocks install busted
  luarocks install luacheck

build:
  moonc src/

test: build
  busted -v spec/

lint: build
  find -name '*.moon' -print -exec moonpick {} \;
  luacheck src/

repl:
  rlwrap -a -H '{{cwd}}/.lua_history' lua
