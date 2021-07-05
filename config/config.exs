# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :chess,
  ecto_repos: [Chess.Repo]

# Configures the endpoint
config :chess, ChessWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "dtTI1SYyQRPFqra1A6fZ0AQTPfOb4dHt2Y0qgY5S0jX/Tax38c6q67ufi3M3rV06",
  render_errors: [view: ChessWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Chess.PubSub,
  live_view: [signing_salt: "dkaJ6HWt"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
