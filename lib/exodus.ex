defmodule Exodus do
  alias Exodus.{Clone, Filter, Merge}

  def main(["clone"]), do: Clone.call()
  def main(["filter"]), do: Filter.call()
  def main(["merge"]), do: Merge.call()
  def main(["all"]) do
    Clone.call()
    Filter.call()
    Merge.call()
  end
end
