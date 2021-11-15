defmodule Fetcher2.Util do
  require Logger

  def debug(arg) do
    Logger.debug(inspect(arg, pretty: true))
  end
end
