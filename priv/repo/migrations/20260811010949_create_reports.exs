defmodule BahaBa.Repo.Migrations.CreateReports do
  use Ecto.Migration

  def change do
    create table(:reports) do
      add :water_level, :string
      add :photo_url, :string
      add :device_hash, :string
      add :flags_count, :integer

      add :latitude, :float, null: false
      add :longitude, :float, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:reports, [:latitude, :longitude])
  end
end
