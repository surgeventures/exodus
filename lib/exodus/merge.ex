defmodule Exodus.Merge do
  alias Exodus.{Config, Repo, Runner}

  def call do
    init()
    link()
    merge()
    unlink()
    cleanup()
  end

  defp init do
    if File.dir?(Config.monorepo_path) do
      final_base = List.last(Config.base_branches)

      [initial_commit_raw] = Runner.run_commands("Get root commit", [
        {~w{git rev-list --all --grep} ++ ["Initial monorepo"], cd: Config.monorepo_path},
      ])

      initial_commit =
        initial_commit_raw
        |> String.split(~r/\s+/)
        |> List.first()

      commands = [
        {~w{git checkout #{final_base}}, cd: Config.monorepo_path},
        {~w{git checkout -b monorepo-base #{initial_commit}}, cd: Config.monorepo_path, ignore_failure: true},
      ]

      Runner.run_commands("Restore monorepo base", commands)
    else
      commands = [
        ~w{mkdir -p #{Config.monorepo_path}},
        {~w{git init}, cd: Config.monorepo_path},
        {~w{git checkout -B monorepo-base}, cd: Config.monorepo_path},
        {~w{git commit --allow-empty --message} ++ ["Initial monorepo"], cd: Config.monorepo_path},
      ]

      Runner.run_commands("Prepare monorepo", commands)
    end
  end

  defp link do
    repos = Repo.all()
    commands = Enum.flat_map(repos, fn repo ->
      path = case Config.merge_method do
        :rewrite -> repo.filtered_path
        :subtree -> repo.mirror_path
      end

      [
        {~w{git remote add #{repo.name} file://#{path}}, cd: Config.monorepo_path, ignore_failure: true},
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
    branch_whitelist = Config.branch_whitelist
    branches =
      (base_branches ++ existing_branches)
      |> Enum.uniq()
      |> Enum.filter(fn branch -> !branch_whitelist || branch in branch_whitelist end)

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
      {~w{git branch -D #{branch}}, cd: Config.monorepo_path, ignore_failure: true},
      {~w{git checkout monorepo-base}, cd: Config.monorepo_path},
      {~w{git checkout -B #{branch}}, cd: Config.monorepo_path},
    ] ++ Enum.flat_map(repo_branch_mapping, fn {repo, repo_branch} ->
      case Config.merge_method do
        :rewrite ->
          [
            {~w{git merge #{repo.name}/#{repo_branch} --no-commit --allow-unrelated-histories}, cd: Config.monorepo_path},
            {~w{git commit --no-verify --allow-empty --message} ++ ["Merge #{repo.name}/#{repo_branch} into monorepo #{branch}"], cd: Config.monorepo_path},
          ]
        :subtree ->
          [
            {~w{git subtree add --prefix=#{repo.nested_path} file://#{repo.mirror_path} #{repo_branch}}, cd: Config.monorepo_path},
          ]
      end
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
