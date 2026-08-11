defmodule BahaBaWeb.PageController do
  use BahaBaWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
