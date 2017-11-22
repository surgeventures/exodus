defmodule Exodus.Filter do
  alias Exodus.{Config, Repo, Runner}

  def call do
    if Config.merge_method == :rewrite do
      init()
      clone()
      filter()
    end
  end

  defp init do
    commands = [
      ~w{rm -rf #{Config.filtered_path}},
      ~w{mkdir -p #{Config.filtered_path}},
    ]

    Runner.run_commands("Prepare workspace for filtered repos", commands)
  end

  defp clone do
    repos = Repo.all()
    commands = Enum.map(repos, fn repo ->
      {~w{git clone --mirror file://#{repo.mirror_path}}, cd: Config.filtered_path}
    end)

    Runner.run_commands_async("Duplicate mirror repos", commands)
  end

  defp filter do
    repos = Repo.all()
    filter_commands = Enum.map(repos, fn repo ->
      {
        [
          "git",
          "filter-branch",
          "--index-filter",
          ~S{tab=$(printf "\t") && git ls-files -s --error-unmatch . >/dev/null 2>&1; [ $? != 0 -o -e } <> repo.nested_path <> ~S{ ] || (git ls-files -s | sed "s~$tab\"*~&} <> repo.nested_path <> ~S{/~" | GIT_INDEX_FILE=$GIT_INDEX_FILE.new git update-index --index-info && mv "$GIT_INDEX_FILE.new" "$GIT_INDEX_FILE")},
          "--",
          "--all",
        ],
        cd: repo.filtered_path
      }
    end)

    Runner.run_commands_async("Rewrite history", filter_commands)
  end
end
