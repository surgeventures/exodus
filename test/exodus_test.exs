defmodule ExodusTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  setup do
    File.rm_rf!("test/output")
    :ok
  end

  @output_master %{
    "test/output/monorepo/apps/repo1/a" => "a3",
    "test/output/monorepo/apps/repo1/dir1/b" => "b1",
    "test/output/monorepo/apps/repo1/dir2/c" => "c1",
    "test/output/monorepo/apps/repo2/a" => "A1",
    "test/output/monorepo/apps/repo2/x" => "X1"
  }

  @output_staging %{
    "test/output/monorepo/apps/repo1/a" => "a4",
    "test/output/monorepo/apps/repo1/d" => "d1",
    "test/output/monorepo/apps/repo1/dir1/b" => "b1",
    "test/output/monorepo/apps/repo1/dir2/c" => "c1",
    "test/output/monorepo/apps/repo2/a" => "A1",
    "test/output/monorepo/apps/repo2/x" => "X1"
  }

  test "rewrite" do
    Application.put_env(:exodus, :merge_method, :rewrite)

    capture_io fn ->
      Exodus.main(["all"])
    end

    assert read_output("monorepo") == @output_master

    capture_io fn ->
      exec_with_output("monorepo", ~w{git checkout staging})
    end

    assert read_output("monorepo") == @output_staging
  end

  test "subtree" do
    Application.put_env(:exodus, :merge_method, :subtree)

    capture_io fn ->
      Exodus.main(["all"])
    end

    assert read_output("monorepo") == @output_master

    capture_io fn ->
      exec_with_output("monorepo", ~w{git checkout staging})
    end

    assert read_output("monorepo") == @output_staging
  end

  def read_output(path) do
    "test/output/#{path}/**/*"
    |> Path.wildcard()
    |> Enum.filter(fn path -> !File.dir?(path) end)
    |> Enum.map(fn path -> {path, File.read!(path) |> String.trim} end)
    |> Enum.sort
    |> Map.new
  end

  def exec_with_output(path, [prog | args]) do
    System.cmd(prog, args, cd: "test/output/#{path}", stderr_to_stdout: true)
  end
end
