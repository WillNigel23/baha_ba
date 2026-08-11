# Baha Ba? 🌊

**Baha Ba?** is an open-source, community-driven flood monitoring platform designed to provide real-time updates on road conditions and water levels across the Philippines.

Built with **Elixir**, **Phoenix LiveView**, **Tailwind CSS**, and **LeafletJS**.

---

## 🚀 Features

* **Interactive Live Map:** Pinpoint flood locations with real-time Leaflet map synchronization.
* **Community Reporting:** Submit flood depth levels, photo proof, and exact GPS coordinates.
* **Crowdsourced Moderation:** Upvote or downvote reports to keep data accurate and flag outdated pins.
* **List View:** Switch between map view and a simple chronological feed.

---

## 🛠️ Tech Stack

* **Backend/Frontend:** Elixir, Phoenix LiveView
* **Database:** PostgreSQL / Ecto
* **Mapping:** LeafletJS / OpenStreetMap
* **Image Hosting:** Cloudinary (Direct Upload)

---

## 💻 Getting Started Locally

### Prerequisites

* **Erlang/OTP:** 29 (`erts-17.0.5`)
* **Elixir:** 1.20.3 (compiled with Erlang/OTP 28)
* **PostgreSQL:** Running locally

### Setup Instructions

1. **Clone the repository:**
   ```bash
   git clone [https://github.com/WillNigel23/baha_ba.git](https://github.com/WillNigel23/baha_ba.git)
   cd baha_ba
   ```

2. **Install dependencies:**
   ```bash
   mix setup
   ```

3. **Set environment variables:**
   Create a `.env` file or export your Cloudinary parameters:
   ```bash
   export CLOUDINARY_CLOUD_NAME="your_cloud_name"
   export CLOUDINARY_UPLOAD_PRESET="your_upload_preset"
   ```

4. **Start the Phoenix server:**
   ```bash
   mix phx.server
   ```

Visit [`localhost:4000`](http://localhost:4000) in your browser.

---

## 🤖 AI Assistance Disclaimer

This application was developed with the aid of **Google Gemini** as an AI development assistant to support code implementation, architectural planning, and documentation. All code has been reviewed, tested, and maintained by the author.

---

## 📜 License

Distributed under the **MIT License**. See [LICENSE.md](LICENSE.md) for details.
