defmodule BahaBaWeb.MapLive do
  use BahaBaWeb, :live_view
  alias BahaBa.Flood

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(BahaBa.PubSub, "flood_reports")
    end

    user_ip =
      case get_connect_info(socket, :peer_data) do
        %{address: address} -> :inet.ntoa(address) |> to_string()
        _ -> "127.0.0.1"
      end

    initial_reports = Flood.list_recent_reports()
    initial_reports_json = Enum.map(initial_reports, &sanitize_report/1) |> Jason.encode!()

    {:ok,
     socket
     |> assign(:user_ip, user_ip)
     |> assign(:view_mode, "map")
     |> assign(:water_level, "passable")
     |> assign(:latitude, nil)
     |> assign(:longitude, nil)
     |> assign(:reports, initial_reports)
     |> assign(:initial_reports_json, initial_reports_json)
     |> assign(:show_about_modal, false)
     |> allow_upload(:photo,
       accept: ~w(.jpg .jpeg .png .heic .heif .webp),
       max_entries: 1,
       max_file_size: 25_000_000,
       external: &presign_cloudinary/2
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="h-dvh w-screen relative overflow-hidden bg-slate-100 flex flex-col">
      <!-- Top Bar: Search + View Toggle + About Modal Button -->
      <div class="absolute top-3 left-3 right-3 z-20 flex gap-2 items-center pointer-events-none">
        <div class="flex-1 bg-white/95 backdrop-blur-md rounded-xl shadow-md border border-slate-200 flex items-center px-3 py-1.5 pointer-events-auto">
          <span class="text-slate-400 mr-2">🔍</span>
          <input
            id="location-search-input"
            type="text"
            placeholder="Search city/barangay & press Enter..."
            class="w-full bg-transparent text-sm font-medium border-0 focus:ring-0 p-1 text-slate-800 placeholder-slate-400 outline-none"
          />
        </div>

        <button
          phx-click="toggle_view_mode"
          class="bg-slate-900 hover:bg-slate-800 text-white text-xs font-bold px-3 py-3 rounded-xl shadow-md shrink-0 flex items-center gap-1 pointer-events-auto cursor-pointer transition-all"
        >
          <%= if @view_mode == "map", do: "📋 List View", else: "🗺️ Map View" %>
        </button>

        <button
          type="button"
          phx-click="open_about_modal"
          class="bg-white hover:bg-slate-50 text-slate-700 text-xs font-bold p-3 rounded-xl shadow-md border border-slate-200 shrink-0 flex items-center justify-center pointer-events-auto cursor-pointer transition-all"
          aria-label="About Baha Ba?"
        >
          <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
        </button>
      </div>

      <!-- Map Canvas Container with Preloaded Data -->
      <div
        id="leaflet-map-canvas"
        phx-hook="MapHook"
        phx-update="ignore"
        data-initial-reports={@initial_reports_json}
        class={"absolute inset-0 w-full h-full z-0 " <> if(@view_mode == "feed", do: "hidden", else: "block")}
      ></div>

      <!-- Feed / List View -->
      <%= if @view_mode == "feed" do %>
        <div class="flex-1 overflow-y-auto p-4 pt-20 pb-80 space-y-4 bg-slate-100 z-10">
          <h2 class="text-lg font-black text-slate-800">Recent Flood Reports</h2>
          <%= if @reports == [] do %>
            <p class="text-sm text-slate-500 italic">No active reports in this area.</p>
          <% else %>
            <div class="grid gap-3">
              <%= for report <- @reports do %>
                <div class="bg-white rounded-2xl p-3 shadow-sm border border-slate-200 flex gap-3 items-center">
                  <img src={report.photo_url} class="w-20 h-20 object-cover rounded-xl shrink-0 bg-slate-200" />
                  <div class="flex-1 min-w-0">
                    <span class={"inline-block px-2 py-0.5 text-[10px] font-black uppercase text-white rounded-md mb-1 " <> water_level_color(report.water_level)}>
                      <%= report.water_level %>
                    </span>
                    <p class="text-xs text-slate-500 font-medium">
                      {format_pht_time(report.inserted_at)}
                    </p>
                    <button
                      phx-click="flag_report"
                      phx-value-id={report.id}
                      class="text-[10px] text-red-500 font-semibold mt-1 hover:underline"
                    >
                      🚩 Report Outdated/Fake
                    </button>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>

      <!-- Bottom Submission Form Drawer -->
      <div class="fixed bottom-0 left-0 right-0 p-4 bg-white shadow-2xl rounded-t-2xl z-20 space-y-3 max-w-md mx-auto border-t border-slate-100">
        <.form for={%{}} phx-change="validate" phx-submit="save" class="space-y-3">

          <!-- Location Picker Control -->
          <div class="flex items-center justify-between text-xs bg-slate-50 p-2.5 rounded-xl border border-slate-200">
            <div>
              <span class="font-bold text-slate-700 block">📍 Report Location</span>
              <%= if @latitude && @longitude do %>
                <span class="text-emerald-600 font-bold text-[11px]">
                  Pinned (<%= Float.round(@latitude, 4) %>, <%= Float.round(@longitude, 4) %>)
                </span>
              <% else %>
                <span class="text-amber-600 font-semibold text-[11px] italic">No location selected</span>
              <% end %>
            </div>

            <button
              type="button"
              phx-click="drop_pin"
              class="bg-orange-600 hover:bg-orange-700 text-white text-xs font-bold px-3 py-2 rounded-lg shadow-sm transition-all flex items-center gap-1 active:scale-95"
            >
              📍 <%= if @latitude, do: "Reposition Pin", else: "Select Location" %>
            </button>
          </div>

          <div>
            <label class="block text-xs font-bold text-slate-700 mb-1.5 uppercase tracking-wide">Water Depth</label>
            <div class="grid grid-cols-4 gap-1.5">
              <%= for {level, label, color} <- [
                {"passable", "Passable", "bg-green-600"},
                {"moderate", "Moderate", "bg-yellow-500"},
                {"severe", "Severe", "bg-red-600"},
                {"cleared", "Cleared", "bg-slate-500"}
              ] do %>
                <button
                  type="button"
                  phx-click="set_water_level"
                  phx-value-level={level}
                  class={"py-2 px-1 text-[11px] font-bold text-white rounded-lg transition-all " <>
                    color <> if(@water_level == level, do: " ring-2 ring-slate-900 scale-105", else: " opacity-60")}
                >
                  <%= label %>
                </button>
              <% end %>
            </div>
          </div>

          <div>
            <.live_file_input upload={@uploads.photo} phx-hook="ResizeUpload" class="block w-full text-xs text-slate-500 file:mr-3 file:py-1.5 file:px-3 file:rounded-lg file:border-0 file:text-xs file:font-bold file:bg-orange-50 file:text-orange-700 hover:file:bg-orange-100" />
          </div>

          <button
            type="submit"
            disabled={@uploads.photo.entries == [] or is_nil(@latitude)}
            class="w-full py-2.5 bg-orange-600 text-white text-sm font-black rounded-xl disabled:bg-slate-300 transition-all shadow-md"
          >
            SUBMIT FLOOD REPORT
          </button>
        </.form>
      </div>

      <!-- About Modal -->
      <%= if @show_about_modal do %>
        <div class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-sm">
          <div class="bg-white rounded-2xl shadow-xl border border-slate-200 max-w-sm w-full p-5 space-y-4 relative">
            <button
              type="button"
              phx-click="close_about_modal"
              class="absolute top-4 right-4 text-slate-400 hover:text-slate-600 font-bold p-1 rounded-lg transition"
            >
              ✕
            </button>

            <div class="border-b border-slate-100 pb-2">
              <h2 class="text-lg font-black text-slate-900">About Baha Ba?</h2>
            </div>

            <p class="text-xs leading-relaxed text-slate-600">
              <strong>Baha Ba?</strong> is an open-source, community-driven flood monitoring platform designed to provide real-time updates on road conditions and water levels across the Philippines.
            </p>

            <div class="rounded-xl bg-slate-50 p-3 text-xs space-y-2 border border-slate-200">
              <div class="flex items-center justify-between">
                <span class="font-medium text-slate-600">Open Source</span>
                <a
                  href="https://github.com/WillNigel23/baha_ba"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="text-blue-600 hover:text-blue-700 hover:underline font-bold flex items-center gap-1"
                >
                  GitHub Repository
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-3 w-3 inline" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                  </svg>
                </a>
              </div>

              <div class="flex items-center justify-between">
                <span class="font-medium text-slate-600">Author</span>
                <span class="text-slate-900 font-bold">Will Nigel De Jesus</span>
              </div>

              <div class="flex items-center justify-between">
                <span class="font-medium text-slate-600">Contact</span>
                <a href="mailto:willnigelcdejesus@gmail.com" class="text-blue-600 hover:text-blue-700 hover:underline font-medium">
                  willnigelcdejesus@gmail.com
                </a>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def handle_event("open_about_modal", _params, socket) do
    {:noreply, assign(socket, :show_about_modal, true)}
  end

  def handle_event("close_about_modal", _params, socket) do
    {:noreply, assign(socket, :show_about_modal, false)}
  end

  def handle_event("drop_pin", _params, socket) do
    {:noreply, push_event(socket, "trigger_drop_pin", %{})}
  end

  def handle_event("toggle_view_mode", _params, socket) do
    new_mode = if socket.assigns.view_mode == "map", do: "feed", else: "map"
    {:noreply, assign(socket, :view_mode, new_mode)}
  end

  def handle_event("set_water_level", %{"level" => level}, socket) do
    {:noreply, assign(socket, :water_level, level)}
  end

  def handle_event("select_location", %{"latitude" => lat, "longitude" => lng}, socket) do
    {:noreply, assign(socket, latitude: lat, longitude: lng)}
  end

  def handle_event("map_bounds_changed", bounds, socket) do
    reports = Flood.list_active_reports_in_bounds(bounds)
    payload = Enum.map(reports, &sanitize_report/1)

    {:noreply, socket |> assign(:reports, reports) |> push_event("load_pins", %{reports: payload})}
  end

  def handle_event("flag_report", %{"id" => id}, socket) do
    case Flood.flag_report(id) do
      {:ok, _} -> {:noreply, put_flash(socket, :info, "Report flagged.")}
      _ -> {:noreply, socket}
    end
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("save", _params, socket) do
    photo_urls =
      consume_uploaded_entries(socket, :photo, fn meta, _entry ->
        {:ok, meta.photo_url}
      end)

    photo_url = List.first(photo_urls)

    report_params = %{
      "latitude" => socket.assigns.latitude,
      "longitude" => socket.assigns.longitude,
      "water_level" => socket.assigns.water_level,
      "photo_url" => photo_url
    }

    case Flood.create_report(report_params, socket.assigns.user_ip) do
      {:ok, report} ->
        updated_reports = [report | socket.assigns.reports]

        # Broadcast live report event to all connected users
        Phoenix.PubSub.broadcast(BahaBa.PubSub, "flood_reports", {:new_report, report})

        {:noreply,
         socket
         |> assign(:reports, updated_reports)
         |> assign(:latitude, nil)
         |> assign(:longitude, nil)
         |> put_flash(:info, "Report submitted successfully!")
         |> push_event("clear_selection_pin", %{})}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not save report.")}
    end
  end

  def handle_event("vote", %{"id" => report_id, "type" => type}, socket) do
    case Flood.vote_report(report_id, socket.assigns.user_ip, type) do
      {:ok, _report} ->
        {:noreply, put_flash(socket, :info, "Vote recorded!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not submit vote.")}
    end
  end

  # PubSub listener for vote count changes
  def handle_info({:vote_updated, report}, socket) do
    sanitized = sanitize_report(report)
    {:noreply, push_event(socket, "update_pin_votes", %{report: sanitized})}
  end

  # PubSub listener when downvote threshold hides a pin
  def handle_info({:report_hidden, report_id}, socket) do
    updated_reports = Enum.reject(socket.assigns.reports, &(&1.id == report_id))

    {:noreply,
     socket
     |> assign(:reports, updated_reports)
     |> push_event("remove_pin", %{id: report_id})}
  end

  # Real-time PubSub handler for live updates across all open clients
  def handle_info({:new_report, report}, socket) do
    sanitized = sanitize_report(report)
    updated_reports = [report | socket.assigns.reports]

    {:noreply,
     socket
     |> assign(:reports, updated_reports)
     |> push_event("add_pin", %{report: sanitized})}
  end

  defp water_level_color("passable"), do: "bg-green-600"
  defp water_level_color("moderate"), do: "bg-yellow-500"
  defp water_level_color("severe"), do: "bg-red-600"
  defp water_level_color(_), do: "bg-slate-500"

  defp format_pht_time(nil), do: ""
  defp format_pht_time(naive_datetime) do
    # Shift UTC time by +8 hours for Philippine Standard Time (PHT)
    pht_time = NaiveDateTime.add(naive_datetime, 8 * 3600, :second)
    "As of " <> Calendar.strftime(pht_time, "%b %d, %I:%M %p")
  end

  defp sanitize_report(report) do
    %{
      id: report.id,
      latitude: report.latitude,
      longitude: report.longitude,
      water_level: report.water_level,
      photo_url: report.photo_url,
      upvotes_count: report.upvotes_count,
      downvotes_count: report.downvotes_count,
      inserted_at: report.inserted_at,
      as_of: format_pht_time(report.inserted_at)
    }
  end

  defp presign_cloudinary(entry, socket) do
    cloud_name = System.get_env("CLOUDINARY_CLOUD_NAME")
    upload_preset = System.get_env("CLOUDINARY_UPLOAD_PRESET")

    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    # Prefix the public_id with your folder name
    public_id = "baha_ba/flood_report_#{entry.ref}_#{timestamp}"

    meta = %{
      uploader: "CloudinaryDirectUpload",
      url: "https://api.cloudinary.com/v1_1/#{cloud_name}/image/upload",
      upload_preset: upload_preset,
      public_id: public_id,
      photo_url: "https://res.cloudinary.com/#{cloud_name}/image/upload/#{public_id}"
    }

    {:ok, meta, socket}
  end
end
