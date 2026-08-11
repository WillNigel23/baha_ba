defmodule BahaBa.Repo do
  use Ecto.Repo,
    otp_app: :baha_ba,
    adapter: Ecto.Adapters.Postgres
end
