defmodule Exodus.Config do
  def merge_method, do: Application.get_env(:exodus, :merge_method, :rewrite)

  def mirror_path, do: Application.get_env(:exodus, :mirror_path)

  def filtered_path, do: Application.get_env(:exodus, :filtered_path)

  def monorepo_path, do: Application.get_env(:exodus, :monorepo_path)

  def nested_root, do: Application.get_env(:exodus, :nested_root)

  def base_branches, do: Application.get_env(:exodus, :base_branches)

  def branch_whitelist, do: Application.get_env(:exodus, :branch_whitelist)

  def repo_names, do: Application.get_env(:exodus, :repo_names)

  def remote_base, do: Application.get_env(:exodus, :remote_base)
end
