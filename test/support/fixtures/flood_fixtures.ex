defmodule BahaBa.FloodFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `BahaBa.Flood` context.
  """

  @doc """
  Generate a report.
  """
  def report_fixture(attrs \\ %{}) do
    {:ok, report} =
      attrs
      |> Enum.into(%{
        "latitude" => 14.5995,
        "longitude" => 120.9842,
        "water_level" => "passable",
        "photo_url" => "https://example.com/flood.jpg"
      })
      |> BahaBa.Flood.create_report()

    report
  end
end
