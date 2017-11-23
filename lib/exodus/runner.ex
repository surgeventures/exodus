defmodule Exodus.Runner do
  def run_commands(message, cmds) do
    IO.puts("#{message} (#{length cmds} command(s))")
    start_time = :os.system_time(:seconds)
    results = Enum.map(cmds, &run_command/1)
    end_time = :os.system_time(:seconds)
    IO.puts("Completed after #{end_time - start_time} second(s)")
    IO.puts("")
    results
  end

  def run_commands_async(message, cmds) do
    IO.puts("#{message} (#{length cmds} parallel command(s))")
    start_time = :os.system_time(:seconds)
    cmd_pids = Enum.map(cmds, fn cmd -> Task.async(fn -> run_command(cmd) end) end)
    results = Enum.map(cmd_pids, &Task.await(&1, :infinity))
    end_time = :os.system_time(:seconds)
    IO.puts("Completed after #{end_time - start_time} second(s)")
    IO.puts("")
    results
  end

  def run_command(cmd) when is_list(cmd), do: run_command({cmd, []})
  def run_command({cmd = [prog | args], opts}) do
    id = generate_id()
    ignore_failure = Keyword.get(opts, :ignore_failure, false)
    log_file = "/tmp/exodus.runner.#{id}.log"
    log_stream = File.stream!(log_file, [:delayed_write])
    final_opts =
      opts
      |> Keyword.merge(stderr_to_stdout: true, into: log_stream)
      |> Keyword.drop([:ignore_failure])

    IO.puts "#{id} > #{inspect_command(cmd)}"

    case {ignore_failure, System.cmd(prog, args, final_opts)} do
      {false, {output, code}} when code > 0 ->
        output_string = Enum.into(output, "")
        File.rm(log_file)
        IO.puts "Failure (#{code}) from #{inspect_command(cmd)}:\n#{output_string}"
        raise(RuntimeError, "Command `#{prog}` failed")
      {_, {output, _code}} ->
        output_string = Enum.into(output, "")
        File.rm(log_file)
        output_string
    end
  end

  defp inspect_command(cmd) do
    cmd
    |> Enum.map(&quote_argument/1)
    |> Enum.join(" ")
    |> String.replace(System.cwd <> "/", "")
  end

  defp quote_argument(arg) do
    if String.contains?(arg, " ") do
      if String.contains?(arg, "\"") do
        ~s{'#{arg}'}
      else
        ~s{"#{arg}"}
      end
    else
      arg
    end
  end

  defp generate_id do
    1..8
    |> Enum.map(fn _ -> Enum.random(0..9) end)
    |> Enum.join
  end
end

