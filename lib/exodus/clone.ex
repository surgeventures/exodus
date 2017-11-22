defmodule Exodus.Clone do
  alias Exodus.{Config, Repo, Runner}

  def call do
    init()
    clone()
  end

  defp init do
    commands = [
      ~w{rm -rf #{Config.mirror_path}},
      ~w{mkdir -p #{Config.mirror_path}},
    ]

    Runner.run_commands("Prepare workspace for cloning", commands)
  end

  defp clone do
    commands = Enum.map(Repo.all(), fn repo ->
      {~w{git clone --mirror #{repo.remote_repo}}, cd: Config.mirror_path}
    end)

    Runner.run_commands_async("Clone remotes to mirror repos", commands)
  end
end
