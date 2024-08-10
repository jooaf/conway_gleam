defmodule ShellUtils do
  def run_command(command, args) do
    case System.cmd(command, args) do
      {output, 0} -> {:ok, output}
      {output, status} -> {:error, {status, output}}
    end
  end
end


