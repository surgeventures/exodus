defmodule Exodus.Repo do
  alias Exodus.Config

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
        remote_repo: "#{Config.remote_base}/#{name}",
        mirror_path: Path.expand("#{Config.mirror_path}/#{name}.git"),
        filtered_path: Path.expand("#{Config.filtered_path}/#{name}.git"),
        nested_path: "#{Config.nested_root}#{name}",
      }
    end)
  end
end
