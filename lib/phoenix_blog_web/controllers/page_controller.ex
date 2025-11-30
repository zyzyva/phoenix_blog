defmodule PhoenixBlogWeb.PageController do
  use PhoenixBlogWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
