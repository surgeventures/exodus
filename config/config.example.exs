use Mix.Config

config :exodus,
  mirror_path: "output/repos/mirror",
  filtered_path: "output/repos/filtered",
  monorepo_path: "output/monorepo",
  base_branches: ~w{staging master},
  remote_base: "git@github.com:myorganization",
  repo_names: ~w{myproject1 myproject2}
