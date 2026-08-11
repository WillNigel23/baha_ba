import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import topbar from "../vendor/topbar"
import { MapHook } from "./hooks/map_hook"
import { ResizeUpload } from "./hooks/resize_hook"

let Hooks = { MapHook, ResizeUpload }

// Custom LiveView Direct Uploader for Cloudinary
let Uploaders = {}

Uploaders.CloudinaryDirectUpload = function(entries, onViewError) {
  entries.forEach(entry => {
    let formData = new FormData()
    let { url, upload_preset, public_id } = entry.meta

    formData.append("file", entry.file)
    formData.append("upload_preset", upload_preset)
    formData.append("public_id", public_id)

    let xhr = new XMLHttpRequest()
    onViewError(() => xhr.abort())

    xhr.upload.addEventListener("progress", (event) => {
      if (event.lengthComputable) {
        let percent = Math.round((event.loaded / event.total) * 100)
        entry.progress(percent)
      }
    })

    xhr.onload = () => {
      if (xhr.status >= 200 && xhr.status < 300) {
        entry.progress(100)
      } else {
        console.error("[CloudinaryUpload] Failed:", xhr.responseText)
        entry.error()
      }
    }

    xhr.onerror = () => entry.error()

    xhr.open("POST", url, true)
    xhr.send(formData)
  })
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: Hooks,
  uploaders: Uploaders
})

topbar.config({ barColors: { 0: "#22c55e" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

liveSocket.connect()
window.liveSocket = liveSocket
