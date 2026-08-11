defmodule BahaBa.FloodTest do
  use BahaBa.DataCase, async: true

  alias BahaBa.Flood
  alias BahaBa.Flood.Report
  alias BahaBa.Flood.Vote

  @valid_attrs %{
    "latitude" => 14.5995,
    "longitude" => 120.9842,
    "water_level" => "passable",
    "photo_url" => "http://example.com/flood.jpg"
  }

  @invalid_attrs %{
    "latitude" => nil,
    "longitude" => nil,
    "water_level" => nil
  }

  def report_fixture(attrs \\ %{}) do
    {:ok, report} =
      attrs
      |> Enum.into(%{
        latitude: 14.5995,
        longitude: 120.9842,
        water_level: "passable",
        photo_url: "http://example.com/flood.jpg"
      })
      |> Flood.create_report()

    report
  end

  describe "list_reports/0 and get_report!/1" do
    test "list_reports/0 returns all reports" do
      report = report_fixture()
      assert Flood.list_reports() == [report]
    end

    test "get_report!/1 returns the report with given id" do
      report = report_fixture()
      assert Flood.get_report!(report.id) == report
    end

    test "get_report!/1 raises Ecto.NoResultsError for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Flood.get_report!(0)
      end
    end
  end

  describe "create_report/2" do
    test "with valid data creates a report and broadcasts to PubSub" do
      Phoenix.PubSub.subscribe(BahaBa.PubSub, "flood_reports")

      assert {:ok, %Report{} = report} = Flood.create_report(@valid_attrs)
      assert report.latitude == 14.5995
      assert report.longitude == 120.9842
      assert report.water_level == "passable"

      assert_receive {:new_report, ^report}
    end

    test "normalizes string latitude and longitude attributes" do
      attrs = Map.merge(@valid_attrs, %{"latitude" => "14.5995", "longitude" => "120.9842"})

      assert {:ok, %Report{} = report} = Flood.create_report(attrs)
      assert report.latitude == 14.5995
      assert report.longitude == 120.9842
    end

    test "with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Flood.create_report(@invalid_attrs)
    end
  end

  describe "flag_report/1" do
    test "increments flags_count for valid report id" do
      report = report_fixture()
      assert {:ok, report_id} = Flood.flag_report(report.id)
      assert report_id == report.id

      updated_report = Flood.get_report!(report.id)
      assert updated_report.flags_count == 1
    end

    test "returns error for non-existent report id" do
      assert {:error, :not_found} = Flood.flag_report(0)
    end
  end

  describe "update_report/2 and delete_report/1" do
    test "update_report/2 with valid data updates the report" do
      report = report_fixture()
      assert {:ok, %Report{} = updated} = Flood.update_report(report, %{water_level: "severe"})
      assert updated.water_level == "severe"
    end

    test "delete_report/1 deletes the report" do
      report = report_fixture()
      assert {:ok, %Report{}} = Flood.delete_report(report)
      assert_raise Ecto.NoResultsError, fn -> Flood.get_report!(report.id) end
    end

    test "change_report/2 returns a report changeset" do
      report = report_fixture()
      assert %Ecto.Changeset{} = Flood.change_report(report)
    end
  end

  describe "list_active_reports_in_bounds/1 and list_recent_reports/0" do
    test "list_active_reports_in_bounds/1 filters by bounding box, age, and hidden status" do
      # Active report inside bounds
      in_bounds = report_fixture(%{latitude: 14.5, longitude: 121.0})

      # Out of bounds report
      _out_of_bounds = report_fixture(%{latitude: 20.0, longitude: 121.0})

      # Hidden report inside bounds
      _hidden = report_fixture(%{latitude: 14.5, longitude: 121.0, hidden: true})

      # Old report inside bounds (> 1 hour ago)
      old_time = NaiveDateTime.utc_now() |> NaiveDateTime.add(-3601, :second) |> NaiveDateTime.truncate(:second)
      old_report = report_fixture(%{latitude: 14.5, longitude: 121.0})
      Repo.update_all(from(r in Report, where: r.id == ^old_report.id), set: [inserted_at: old_time])

      bounds = %{"north" => 15.0, "south" => 14.0, "east" => 122.0, "west" => 120.0}
      reports = Flood.list_active_reports_in_bounds(bounds)

      assert length(reports) == 1
      assert hd(reports).id == in_bounds.id
    end

    test "list_active_reports_in_bounds/1 returns empty list for invalid bounds format" do
      assert Flood.list_active_reports_in_bounds(%{}) == []
    end

    test "list_recent_reports/0 returns non-hidden reports created in the last hour" do
      recent = report_fixture()
      _hidden = report_fixture(%{hidden: true})

      reports = Flood.list_recent_reports()
      assert length(reports) == 1
      assert hd(reports).id == recent.id
    end
  end

  describe "vote_report/3" do
    setup do
      Phoenix.PubSub.subscribe(BahaBa.PubSub, "flood_reports")
      report = report_fixture()
      %{report: report}
    end

    test "creates a vote and recalculates counts", %{report: report} do
      assert {:ok, %Report{} = updated_report} = Flood.vote_report(report.id, "192.168.1.1", "up")

      assert updated_report.upvotes_count == 1
      assert updated_report.downvotes_count == 0
      assert updated_report.hidden == false

      assert Repo.get_by(Vote, report_id: report.id, user_ip: "192.168.1.1").vote_type == "up"
      assert_receive {:vote_updated, ^updated_report}
    end

    test "allows user to change vote from up to down", %{report: report} do
      {:ok, _} = Flood.vote_report(report.id, "192.168.1.1", "up")
      {:ok, updated_report} = Flood.vote_report(report.id, "192.168.1.1", "down")

      assert updated_report.upvotes_count == 0
      assert updated_report.downvotes_count == 1
      assert Repo.aggregate(Vote, :count) == 1
    end

    test "auto-hides report and broadcasts report_hidden when net score reaches downvote threshold (-3)", %{report: report} do
      {:ok, _} = Flood.vote_report(report.id, "10.0.0.1", "down")
      {:ok, _} = Flood.vote_report(report.id, "10.0.0.2", "down")
      {:ok, updated_report} = Flood.vote_report(report.id, "10.0.0.3", "down")

      assert updated_report.downvotes_count == 3
      assert updated_report.upvotes_count == 0
      assert updated_report.hidden == true

      assert_receive {:report_hidden, report_id}
      assert report_id == report.id
    end
  end
end
