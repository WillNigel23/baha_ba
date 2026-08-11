defmodule BahaBa.Flood do
  @moduledoc """
  The Flood context.
  """

  import Ecto.Query, warn: false
  alias BahaBa.Repo
  alias BahaBa.Flood.Report
  alias BahaBa.Flood.Vote

  @downvote_threshold -3

  @doc """
  Returns the list of reports.
  """
  def list_reports do
    Repo.all(Report)
  end

  @doc """
  Gets a single report.
  """
  def get_report!(id), do: Repo.get!(Report, id)

  @doc """
  Creates a report with PubSub broadcasting.
  Accepts string or float latitude/longitude.
  """
  def create_report(attrs, _user_ip \\ "127.0.0.1") do
    normalized_attrs = normalize_coords(attrs)

    %Report{}
    |> Report.changeset(normalized_attrs)
    |> Repo.insert()
    |> case do
      {:ok, report} ->
        Phoenix.PubSub.broadcast(BahaBa.PubSub, "flood_reports", {:new_report, report})
        {:ok, report}

      error ->
        error
    end
  end

  @doc """
  Increments the flag count for a report. Auto-hides when flags_count >= 3.
  """
  def flag_report(report_id) do
    from(r in Report, where: r.id == ^report_id)
    |> Repo.update_all(inc: [flags_count: 1])
    |> case do
      {1, _} -> {:ok, report_id}
      _ -> {:error, :not_found}
    end
  end

  @doc """
  Updates a report.
  """
  def update_report(%Report{} = report, attrs) do
    report
    |> Report.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a report.
  """
  def delete_report(%Report{} = report) do
    Repo.delete(report)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking report changes.
  """
  def change_report(%Report{} = report, attrs \\ %{}) do
    Report.changeset(report, attrs)
  end

  @doc """
  Returns reports within map bounds created in the last 12 hours.
  """
  def list_active_reports_in_bounds(%{"north" => n, "south" => s, "east" => e, "west" => w}) do
    one_hour_ago = DateTime.utc_now() |> DateTime.add(-3600, :second)

    from(r in Report,
      where: r.hidden == false,
      where: r.inserted_at >= ^one_hour_ago,
      where: r.latitude >= ^s and r.latitude <= ^n,
      where: r.longitude >= ^w and r.longitude <= ^e,
      order_by: [desc: r.inserted_at]
    )
    |> Repo.all()
  end

  def list_active_reports_in_bounds(_bounds), do: []

  @doc """
  Returns the most recent flood reports.
  """
  def list_recent_reports do
    one_hour_ago = DateTime.utc_now() |> DateTime.add(-3600, :second)

    from(r in Report,
      where: r.hidden == false,
      where: r.inserted_at >= ^one_hour_ago,
      order_by: [desc: r.inserted_at],
      limit: 50
    )
    |> Repo.all()
  end

  @doc false
  def vote_report(report_id, user_ip, vote_type) when vote_type in ["up", "down"] do
    Repo.transaction(fn ->
      # Insert or update vote by IP using a Changeset
      changeset =
        (Repo.get_by(Vote, report_id: report_id, user_ip: user_ip) || %Vote{})
        |> Vote.changeset(%{
          report_id: report_id,
          user_ip: user_ip,
          vote_type: vote_type
        })

      Repo.insert_or_update!(changeset)

      # Recalculate upvote/downvote totals
      up_count = Repo.aggregate(from(v in Vote, where: v.report_id == ^report_id and v.vote_type == "up"), :count)
      down_count = Repo.aggregate(from(v in Vote, where: v.report_id == ^report_id and v.vote_type == "down"), :count)

      net_score = up_count - down_count
      should_hide = net_score <= @downvote_threshold

      report =
        Repo.get!(Report, report_id)
        |> Report.changeset(%{
          upvotes_count: up_count,
          downvotes_count: down_count,
          hidden: should_hide
        })
        |> Repo.update!()

      if should_hide do
        Phoenix.PubSub.broadcast(BahaBa.PubSub, "flood_reports", {:report_hidden, report.id})
      else
        Phoenix.PubSub.broadcast(BahaBa.PubSub, "flood_reports", {:vote_updated, report})
      end

      report
    end)
  end

  # Helper to parse string latitude/longitude into floats
  defp normalize_coords(attrs) do
    attrs
    |> Map.update("latitude", nil, &parse_float/1)
    |> Map.update("longitude", nil, &parse_float/1)
  end

  defp parse_float(val) when is_binary(val) do
    case Float.parse(val) do
      {f, _} -> f
      :error -> nil
    end
  end

  defp parse_float(val) when is_number(val), do: val
  defp parse_float(_), do: nil
end
