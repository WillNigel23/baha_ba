const L = window.L

export const MapHook = {
  mounted() {
    const defaultCenter = [14.5995, 120.9842]

    const phBounds = L.latLngBounds(
      L.latLng(4.5, 115.0),
      L.latLng(21.5, 127.0)
    )

    this.map = L.map(this.el, {
      center: defaultCenter,
      zoom: 15,
      minZoom: 6,
      maxZoom: 18,
      maxBounds: phBounds,
      maxBoundsViscosity: 1.0,
      zoomControl: false,
      tap: false
    })

    L.control.zoom({ position: "bottomright" }).addTo(this.map)

    L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution: "&copy; OpenStreetMap contributors"
    }).addTo(this.map)

    this.reportMarkers = {}
    this.selectedMarker = null

    this.safePushEvent = (eventName, payload) => {
      try {
        const res = this.pushEvent(eventName, payload)
        if (res && typeof res.catch === "function") {
          res.catch(err => console.warn(`[MapHook] '${eventName}' deferred:`, err))
        }
      } catch (err) {
        console.warn(`[MapHook] '${eventName}' push failed:`, err)
      }
    }

    const pushBounds = () => {
      const bounds = this.map.getBounds()
      this.safePushEvent("map_bounds_changed", {
        north: bounds.getNorth(),
        south: bounds.getSouth(),
        east: bounds.getEast(),
        west: bounds.getWest()
      })
    }

    // Load initial reports passed via data attribute
    if (this.el.dataset.initialReports) {
      try {
        const initialReports = JSON.parse(this.el.dataset.initialReports)
        initialReports.forEach(report => this.addReportPin(report))
      } catch (e) {
        console.error("[MapHook] Error parsing initial reports:", e)
      }
    }

    // Recalculate container size and push visible bounds
    setTimeout(() => {
      this.map.invalidateSize()
      pushBounds()
    }, 200)

    // Geolocation to center map on load
    if ("geolocation" in navigator) {
      navigator.geolocation.getCurrentPosition(
        (pos) => {
          const { latitude, longitude } = pos.coords
          this.map.setView([latitude, longitude], 16)
          this.map.invalidateSize()
          pushBounds()
        },
        (err) => console.warn("[MapHook] Geolocation permission denied or unavailable:", err.message),
        { enableHighAccuracy: true, timeout: 5000 }
      )
    }

    // Geocoding search input
    const searchInput = document.getElementById("location-search-input")
    if (searchInput) {
      searchInput.addEventListener("keydown", async (e) => {
        if (e.key === "Enter") {
          e.preventDefault()
          const query = searchInput.value.trim()
          if (!query) return

          try {
            const response = await fetch(
              `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(query)}&countrycodes=ph`
            )
            const results = await response.json()

            if (results && results.length > 0) {
              const { lat, lon } = results[0]
              const targetLat = parseFloat(lat)
              const targetLng = parseFloat(lon)

              this.map.flyTo([targetLat, targetLng], 16)
              this.setSelectionPin(targetLat, targetLng)
              this.safePushEvent("select_location", { latitude: targetLat, longitude: targetLng })
            } else {
              alert("Location not found. Try entering a specific city or barangay.")
            }
          } catch (err) {
            console.error("[MapHook] Search request failed:", err)
          }
        }
      })
    }

    const dropPinAtCenter = () => {
      this.map.invalidateSize()
      const center = this.map.getCenter()
      this.setSelectionPin(center.lat, center.lng)
      this.safePushEvent("select_location", { latitude: center.lat, longitude: center.lng })
    }

    this.map.on("click", (e) => {
      const { lat, lng } = e.latlng
      this.setSelectionPin(lat, lng)
      this.safePushEvent("select_location", { latitude: lat, longitude: lng })
    })

    this.map.on("moveend", pushBounds)

    // Use Event Delegation on map container so dynamically re-rendered popup buttons always work
    this.map.getContainer().addEventListener("click", (e) => {
      const btn = e.target.closest(".vote-btn")
      if (btn) {
        e.preventDefault()
        const id = btn.dataset.id
        const type = btn.dataset.type
        this.safePushEvent("vote", { id, type })
      }
    })

    // LiveView Push Event listeners
    this.handleEvent("trigger_drop_pin", dropPinAtCenter)

    this.handleEvent("load_pins", ({ reports }) => {
      reports.forEach(report => this.addReportPin(report))
    })

    this.handleEvent("add_pin", ({ report }) => {
      this.addReportPin(report)
    })

    this.handleEvent("update_pin_votes", ({ report }) => {
      const marker = this.reportMarkers[report.id]
      if (marker) {
        marker.setPopupContent(this.buildPopupHtml(report))
      }
    })

    this.handleEvent("remove_pin", ({ id }) => {
      if (this.reportMarkers[id]) {
        this.map.removeLayer(this.reportMarkers[id])
        delete this.reportMarkers[id]
      }
    })

    this.handleEvent("clear_selection_pin", () => {
      if (this.selectedMarker) {
        this.map.removeLayer(this.selectedMarker)
        this.selectedMarker = null
      }
    })
  },

  destroyed() {
    if (this.map) {
      this.map.remove()
    }
  },

  setSelectionPin(lat, lng) {
    this.map.invalidateSize()

    const svgIcon = L.divIcon({
      className: "selection-pin-wrapper",
      html: `
        <svg width="36" height="48" viewBox="0 0 36 48" fill="none" xmlns="http://www.w3.org/2000/svg" style="filter: drop-shadow(0px 4px 8px rgba(0,0,0,0.4));">
          <path d="M18 0C8.05888 0 0 8.05888 0 18C0 31.5 18 48 18 48C18 48 36 31.5 36 18C36 8.05888 27.9411 0 18 0Z" fill="#EA580C"/>
          <circle cx="18" cy="18" r="8" fill="white"/>
        </svg>
      `,
      iconSize: [36, 48],
      iconAnchor: [18, 48]
    })

    if (this.selectedMarker) {
      this.selectedMarker.setLatLng([lat, lng])
    } else {
      this.selectedMarker = L.marker([lat, lng], {
        icon: svgIcon,
        draggable: true,
        riseOnHover: true,
        zIndexOffset: 1000
      }).addTo(this.map)

      this.selectedMarker.on("dragend", (event) => {
        const position = event.target.getLatLng()
        this.safePushEvent("select_location", {
          latitude: position.lat,
          longitude: position.lng
        })
      })
    }

    this.map.panTo([lat, lng])
  },

  addReportPin(report) {
    if (this.reportMarkers[report.id]) return

    const colorMap = {
      passable: "#16a34a",
      moderate: "#eab308",
      severe: "#dc2626",
      cleared: "#64748b"
    }

    const color = colorMap[report.water_level] || "#64748b"
    const pinIcon = L.divIcon({
      className: "report-pin-wrapper",
      html: `<div style="background-color: ${color}; width: 18px; height: 18px; border-radius: 50%; border: 2px solid white; box-shadow: 0 2px 4px rgba(0,0,0,0.3);"></div>`,
      iconSize: [18, 18],
      iconAnchor: [9, 9]
    })

    const marker = L.marker([report.latitude, report.longitude], { icon: pinIcon })
      .bindPopup(this.buildPopupHtml(report))
      .addTo(this.map)

    this.reportMarkers[report.id] = marker
  },

  buildPopupHtml(report) {
    const upvotes = report.upvotes_count || 0
    const downvotes = report.downvotes_count || 0
    const netScore = upvotes - downvotes
    const scoreDisplay = `${netScore > 0 ? '+' : ''}${netScore}`
    const scoreColor = netScore < 0 ? '#dc2626' : '#16a34a'

    return `
      <div style="font-size: 12px; width: 150px; font-family: system-ui, -apple-system, sans-serif;">
        <b style="text-transform: uppercase; letter-spacing: 0.5px;">${report.water_level}</b><br/>
        <img src="${report.photo_url}" style="width: 100%; height: 85px; object-fit: cover; border-radius: 8px; margin: 6px 0;" />
        <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 4px; background: #f8fafc; padding: 4px 6px; border-radius: 6px; border: 1px solid #e2e8f0;">
          <button data-id="${report.id}" data-type="up" class="vote-btn" style="background:#22c55e; color:white; border:none; padding:3px 8px; border-radius:4px; font-weight:bold; cursor:pointer; font-size:11px;">👍 ${upvotes}</button>
          <span style="font-weight:bold; font-size:12px; color:${scoreColor};">${scoreDisplay}</span>
          <button data-id="${report.id}" data-type="down" class="vote-btn" style="background:#ef4444; color:white; border:none; padding:3px 8px; border-radius:4px; font-weight:bold; cursor:pointer; font-size:11px;">👎 ${downvotes}</button>
        </div>
      </div>
    `
  }
}
