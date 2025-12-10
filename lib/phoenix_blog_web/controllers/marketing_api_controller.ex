defmodule PhoenixBlogWeb.MarketingApiController do
  @moduledoc """
  API endpoint for the marketing-post-action GitHub Action.

  Receives feature/release data and generates social media post drafts.
  """
  use PhoenixBlogWeb, :controller

  alias PhoenixBlog.Social.ContentGenerator

  require Logger

  @doc """
  Generates social media posts from GitHub event data.

  Expected JSON body:
  {
    "type": "pull_request" | "release",
    "title": "Feature title",
    "body": "Description...",
    "url": "https://github.com/...",
    "repo": "owner/repo",
    "author": "username",
    "labels": ["feature", "marketing"],  // for PRs
    "tag": "v1.0.0"  // for releases
  }

  Headers:
  - Authorization: Bearer <api_key>
  - X-Platforms: twitter,linkedin (optional)
  """
  def generate(conn, params) do
    platforms = get_platforms(conn)

    Logger.info("Marketing API: Generating draft post for #{params["repo"]} (#{params["type"]})")

    feature_info = %{
      type: String.to_atom(params["type"] || "pull_request"),
      title: params["title"] || "",
      body: params["body"] || "",
      url: params["url"] || "",
      repo: params["repo"] || "",
      author: params["author"] || "",
      labels: params["labels"] || [],
      tag: params["tag"],
      merged_at: params["merged_at"]
    }

    case ContentGenerator.generate_from_github_event(feature_info, platforms: platforms) do
      {:ok, result} ->
        json(conn, %{
          status: "created",
          post_id: result.post_id,
          platforms: result.platforms,
          message: "Post draft created successfully"
        })

      {:error, reason} ->
        Logger.error("Marketing API: Generation failed - #{reason}")

        conn
        |> put_status(500)
        |> json(%{status: "error", message: reason})
    end
  end

  defp get_platforms(conn) do
    case get_req_header(conn, "x-platforms") do
      [platforms] -> String.split(platforms, ",") |> Enum.map(&String.trim/1)
      _ -> ["twitter", "linkedin"]
    end
  end
end
