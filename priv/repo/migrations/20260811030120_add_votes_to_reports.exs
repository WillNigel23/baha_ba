defmodule BahaBa.Repo.Migrations.AddVotesToReports do
  use Ecto.Migration

  def change do
    alter table(:reports) do
      add :upvotes_count, :integer, default: 0, null: false
      add :downvotes_count, :integer, default: 0, null: false
      add :hidden, :boolean, default: false, null: false
    end

    create table(:report_votes) do
      add :report_id, references(:reports, on_delete: :delete_all), null: false
      add :user_ip, :string, null: false
      add :vote_type, :string, null: false

      timestamps()
    end

    create unique_index(:report_votes, [:report_id, :user_ip])
    create index(:reports, [:inserted_at, :hidden])
  end
end
