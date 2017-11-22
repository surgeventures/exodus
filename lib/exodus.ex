defmodule Exodus do
  defmodule Config do
    def mirror_path, do: Application.get_env(:exodus, :mirror_path)

    def filtered_path, do: Application.get_env(:exodus, :filtered_path)

    def monorepo_path, do: Application.get_env(:exodus, :monorepo_path)

    def base_branches, do: Application.get_env(:exodus, :base_branches)

    def repo_names, do: Application.get_env(:exodus, :repo_names)

    def remote_base, do: Application.get_env(:exodus, :remote_base)
  end

  defmodule Repo do
    defstruct [
      :name,
      :remote_repo,
      :mirror_path,
      :filtered_path,
      :nested_path,
    ]

    def all do
      Enum.map(Config.repo_names(), fn name ->
        %__MODULE__{
          name: name,
          remote_repo: "#{Config.remote_base()}/#{name}",
          mirror_path: Path.expand("#{Config.mirror_path()}/#{name}.git"),
          filtered_path: Path.expand("#{Config.filtered_path()}/#{name}.git"),
          nested_path: "apps/#{name}",
        }
      end)
    end
  end

  defmodule Runner do
    def run_commands(message, cmds) do
      IO.puts("#{message} (#{length cmds} command(s))")
      results = Enum.map(cmds, &run_command/1)
      IO.puts("")
      results
    end

    def run_commands_async(message, cmds) do
      IO.puts("#{message} (#{length cmds} parallel command(s))")
      cmd_pids = Enum.map(cmds, fn cmd -> Task.async(fn -> run_command(cmd) end) end)
      results = Enum.map(cmd_pids, &Task.await(&1, :infinity))
      IO.puts("")
      results
    end

    def run_command(cmd) when is_list(cmd), do: run_command({cmd, []})
    def run_command({cmd = [prog | args], opts}) do
      IO.puts "> #{inspect_command(cmd)}"

      case System.cmd(prog, args, Keyword.merge(opts, stderr_to_stdout: true)) do
        {output, 0} ->
          output
        {output, code} ->
          IO.puts "Failure (#{code}) from #{inspect_command(cmd)}:\n#{output}"
          raise(RuntimeError, "Command failed")
      end
    end

    def inspect_command(cmd) do
      cmd
      |> Enum.join(" ")
      |> String.replace(System.cwd, ".")
    end
  end

  defmodule Clone do
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

  defmodule Filter do
    def call do
      init()
      clone()
      filter()
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

  defmodule Merge do
    def call do
      init()
      link()
      merge()
      unlink()
      cleanup()
    end

    defp init do
      commands = [
        ~w{rm -rf #{Config.monorepo_path}},
        ~w{mkdir -p #{Config.monorepo_path}},
        {~w{git init}, cd: Config.monorepo_path},
        {~w{git checkout -B monorepo-base}, cd: Config.monorepo_path},
        {~w{git commit --allow-empty --message} ++ ["Initial monorepo"], cd: Config.monorepo_path},
      ]

      Runner.run_commands("Prepare monorepo", commands)
    end

    defp link do
      repos = Repo.all()
      commands = Enum.flat_map(repos, fn repo ->
        [
          {~w{git remote add #{repo.name} file://#{repo.mirror_path}}, cd: Config.monorepo_path},
          {~w{git fetch #{repo.name}}, cd: Config.monorepo_path},
        ]
      end)

      Runner.run_commands("Link remotes", commands)
    end

    defp merge do
      repos = Repo.all()
      [branch_output] = Runner.run_commands("Assemble branch list", [
        {~w{git branch -r}, cd: Config.monorepo_path}
      ])

      repo_branches =
        branch_output
        |> String.split("\n")
        |> Enum.map(&extract_repo_branch/1)
        |> Enum.filter(&(&1))

      base_branches = Enum.reverse(Config.base_branches)
      existing_branches = Enum.map(repo_branches, fn {_, branch} -> branch end)
      branches = Enum.uniq(base_branches ++ existing_branches)

      IO.puts("Compute repo-branch mapping (#{length branches} branch(es))")
      commands = Enum.flat_map(branches, fn branch ->
        IO.puts("- target branch #{branch}")
        repo_branch_mapping = compute_repo_branch_mapping(branch, repos, repo_branches)
        Enum.each(repo_branch_mapping, fn {repo, branch} ->
          IO.puts("  - using #{branch} from #{repo.name}")
        end)

        build_branch_commands(branch, repo_branch_mapping)
      end)
      IO.puts("")

      Runner.run_commands("Branch-aware merge", commands)
    end

    defp extract_repo_branch(string) do
      case Regex.run(~r{\s*(.*)/(.*)\s*}, string) do
        [_all, proj, branch] -> {proj, branch}
        _ -> nil
      end
    end

    defp compute_repo_branch_mapping(branch, repos, repo_branches) do
      Enum.map(repos, fn repo ->
        base_branch = Enum.find([branch | Config.base_branches()], fn branch_candidate ->
          Enum.member?(repo_branches, {repo.name, branch_candidate})
        end) || raise("Base branch not found for repo #{repo.name}")

        {repo, base_branch}
      end)
    end

    defp build_branch_commands(branch, repo_branch_mapping) do
      [
        {~w{git checkout monorepo-base}, cd: Config.monorepo_path},
        {~w{git checkout -B #{branch}}, cd: Config.monorepo_path},
      ] ++ Enum.flat_map(repo_branch_mapping, fn {repo, repo_branch} ->
        [
          {~w{git remote add #{repo.name}-#{branch} #{repo.filtered_path}}, cd: Config.monorepo_path},
          {~w{git pull #{repo.name}-#{branch} #{repo_branch} --allow-unrelated-histories}, cd: Config.monorepo_path},
          {~w{git remote rm #{repo.name}-#{branch}}, cd: Config.monorepo_path},
        ]
      end)
    end

    defp unlink do
      repos = Repo.all()
      commands = Enum.map(repos, fn repo ->
        {~w{git remote rm #{repo.name}}, cd: Config.monorepo_path}
      end)

      Runner.run_commands("Unlink remotes", commands)
    end

    defp cleanup do
      final_base = List.last(Config.base_branches)
      commands = [
        {~w{git checkout #{final_base}}, cd: Config.monorepo_path},
        {~w{git checkout .}, cd: Config.monorepo_path},
        {~w{git branch -D monorepo-base}, cd: Config.monorepo_path}
      ]

      Runner.run_commands("Cleanup", commands)
    end
  end

  def main(["clone"]), do: Clone.call()
  def main(["filter"]), do: Filter.call()
  def main(["merge"]), do: Merge.call()
  def main(["all"]) do
    Clone.call()
    Filter.call()
    Merge.call()
  end
end
