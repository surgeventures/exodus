use Mix.Config

config :exodus,
  merge_method: :rewrite,
  nested_root: "apps/",
  mirror_path: "test/output/repos/mirror",
  filtered_path: "test/output/repos/filtered",
  monorepo_path: "test/output/monorepo",
  base_branches: ~w{staging master},
  remote_base: "file://#{System.cwd}/test/fixtures/repos",
  repo_names: ~w{repo1 repo2}
