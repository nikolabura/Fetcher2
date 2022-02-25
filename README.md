# Fetcher2

A replacement for the legacy Fetcher bot.

Fetches UMBC dining hall menu from DineOnCampus API. Invoked via slash commands.

## Configuration

Create `config/config.exs`. Contents:

```elixir
import Config

config :nostrum,
  token: "BOT_TOKEN_HERE"

config :fetcher2,
  testserv_guild_id: 00000000, # guild ID of test server (for testing slash commands)
  excluded_dhall_categories: ["DELI", "THE MARKET", "HUMMUS BAR"]

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase
```

## Running

```
mix run --no-halt
```

Ctrl+C, then "a" to exit.

## Installation

To build:
```
MIX_ENV=prod mix release
```

### systemd setup

Replace the file paths with the absolute path of your own _build/prod/rel directory

```ini
[Unit]
Description=fetcher2 discord bot
After=local-fs.target network.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=/root/fetcher2/_build/prod/rel/fetcher2
ExecStart=/root/fetcher2/_build/prod/rel/fetcher2/bin/fetcher2 start
ExecStop=/root/fetcher2/_build/prod/rel/fetcher2/bin/fetcher2 stop
Environment=LANG=en_US.utf8
Environment=MIX_ENV=prod
SyslogIdentifier=fetcher2
Restart=always

[Install]
WantedBy=multi-user.target
```
