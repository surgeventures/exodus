use Mix.Config

config :exodus,
  # mechanism to use for merging monorepo, one of:
  # - :rewrite - rewrites all history and merges it as if projects were always in monorepo
  # - :subtree - adds and moves repos without touching the history and commit checksums
  merge_method: :rewrite,

  # paths to write mirror repos, filtered repos and final monorepo to
  mirror_path: "output/repos/mirror",
  filtered_path: "output/repos/filtered",
  monorepo_path: "output/monorepo",

  # path to nest repositories in within the monorepo
  nested_root: "apps/",

  # base branches ordered from children to parents
  base_branches: ~w{staging master},

  # branches to export into monorepo (nil means all of them)
  branch_whitelist: ~w{feature-x staging master},

  # base path for cloning remote repos
  remote_base: "git@github.com:myorganization",

  # names of repositories to include in monorepo
  repo_names: ~w{myproject1 myproject2}
