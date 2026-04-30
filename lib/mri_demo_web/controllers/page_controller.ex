defmodule MriDemoWeb.PageController do
  use MriDemoWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
