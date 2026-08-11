defmodule BahaBa.FloodFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `BahaBa.Flood` context.
  """

  @doc """
  Generate a report.
  """
  def report_fixture(attrs \\ %{}) do
    defaults = %{
      "latitude" => 14.5995,
      "longitude" => 120.9842,
      "water_level" => "passable",
      "photo_url" => "http://example.com/flood.jpg"
    }

    # Normalize all keys in attrs to strings to guarantee a 100% string-keyed map
    normalized_attrs =
      Map.new(attrs, fn {k, v} ->
        {to_string(k), v}
      end)

    {:ok, report} =
      defaults
      |> Map.merge(normalized_attrs)
      |> Flood.create_report()

    report
  end
end
