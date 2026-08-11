defmodule BahaBa.Flood.Report do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :latitude, :longitude, :water_level, :photo_url, :inserted_at]}
  schema "reports" do
    field :water_level, :string
    field :photo_url, :string
    field :device_hash, :string
    field :flags_count, :integer
    field :latitude, :float
    field :longitude, :float

    field :upvotes_count, :integer, default: 0
    field :downvotes_count, :integer, default: 0
    field :hidden, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(report, attrs) do
    report
    |> cast(attrs, [:latitude, :longitude, :water_level, :photo_url, :device_hash, :upvotes_count, :downvotes_count, :hidden])
    |> validate_required([:latitude, :longitude, :water_level, :photo_url])
    |> validate_inclusion(:water_level, ~w(passable moderate severe cleared))
  end
end
