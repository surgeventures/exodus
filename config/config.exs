use Mix.Config

if Mix.env == :test do
  import_config "test.exs"
else
  import_config "config.local.exs"
end
