defmodule BahaBa.FloodTest do
  use BahaBa.DataCase

  alias BahaBa.Flood

  describe "reports" do
    alias BahaBa.Flood.Report

    import BahaBa.FloodFixtures

    @invalid_attrs %{water_level: nil, photo_url: nil, device_hash: nil, flags_count: nil}

    test "list_reports/0 returns all reports" do
      report = report_fixture()
      assert Flood.list_reports() == [report]
    end

    test "get_report!/1 returns the report with given id" do
      report = report_fixture()
      assert Flood.get_report!(report.id) == report
    end

    test "create_report/1 with valid data creates a report" do
      valid_attrs = %{water_level: "some water_level", photo_url: "some photo_url", device_hash: "some device_hash", flags_count: 42}

      assert {:ok, %Report{} = report} = Flood.create_report(valid_attrs)
      assert report.water_level == "some water_level"
      assert report.photo_url == "some photo_url"
      assert report.device_hash == "some device_hash"
      assert report.flags_count == 42
    end

    test "create_report/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Flood.create_report(@invalid_attrs)
    end

    test "update_report/2 with valid data updates the report" do
      report = report_fixture()
      update_attrs = %{water_level: "some updated water_level", photo_url: "some updated photo_url", device_hash: "some updated device_hash", flags_count: 43}

      assert {:ok, %Report{} = report} = Flood.update_report(report, update_attrs)
      assert report.water_level == "some updated water_level"
      assert report.photo_url == "some updated photo_url"
      assert report.device_hash == "some updated device_hash"
      assert report.flags_count == 43
    end

    test "update_report/2 with invalid data returns error changeset" do
      report = report_fixture()
      assert {:error, %Ecto.Changeset{}} = Flood.update_report(report, @invalid_attrs)
      assert report == Flood.get_report!(report.id)
    end

    test "delete_report/1 deletes the report" do
      report = report_fixture()
      assert {:ok, %Report{}} = Flood.delete_report(report)
      assert_raise Ecto.NoResultsError, fn -> Flood.get_report!(report.id) end
    end

    test "change_report/1 returns a report changeset" do
      report = report_fixture()
      assert %Ecto.Changeset{} = Flood.change_report(report)
    end
  end
end
