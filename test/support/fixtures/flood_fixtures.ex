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
        device_hash: "some device_hash",
        flags_count: 42,
        photo_url: "some photo_url",
        water_level: "some water_level"
      })
      |> BahaBa.Flood.create_report()

    report
  end
end
