defmodule BahaBa.Flood.Vote do
  use Ecto.Schema
  import Ecto.Changeset

  schema "report_votes" do
    field :user_ip, :string
    field :vote_type, :string
    belongs_to :report, BahaBa.Flood.Report

    timestamps()
  end

  def changeset(vote, attrs) do
    vote
    |> cast(attrs, [:user_ip, :vote_type, :report_id])
    |> validate_required([:user_ip, :vote_type, :report_id])
    |> validate_inclusion(:vote_type, ["up", "down"])
    |> unique_constraint([:report_id, :user_ip])
  end
end
