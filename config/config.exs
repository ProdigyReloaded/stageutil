import Config

config :logger, level: :error

config :logger, :console,
       format: "$time $metadata[$level] $message\n",
       level: :debug

#import_config "#{Mix.env()}.exs"