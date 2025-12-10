defmodule PhoenixBlogWeb.GitHubWebhookController do
  @moduledoc """
  Handles GitHub webhook events for automated content generation.

  Receives events like PR merges and releases, then uses Claude to
  generate social media post drafts.

  ## Setup

  1. Set GITHUB_WEBHOOK_SECRET environment variable
  2. In GitHub repo: Settings → Webhooks → Add webhook
  3. URL: https://your-app.com/api/github/webhook
  4. Content type: application/json
  5. Secret: same as GITHUB_WEBHOOK_SECRET
  6. Events: Pull requests, Releases
  """
  use PhoenixBlogWeb, :controller

  require Logger

  alias PhoenixBlog.Social.ContentGenerator

  @doc """
  Receives and processes GitHub webhook events.
  """
  def handle(conn, params) do
    event_type = get_req_header(conn, "x-github-event") |> List.first()
    delivery_id = get_req_header(conn, "x-github-delivery") |> List.first()

    Logger.info("GitHub webhook received: #{event_type} (#{delivery_id})")

    case process_event(event_type, params) do
      {:ok, result} ->
        json(conn, %{status: "ok", result: result})

      {:skip, reason} ->
        Logger.info("Skipping event: #{reason}")
        json(conn, %{status: "skipped", reason: reason})

      {:error, reason} ->
        Logger.error("Failed to process webhook: #{reason}")
        conn |> put_status(500) |> json(%{status: "error", reason: reason})
    end
  end

  # Process pull request events
  defp process_event("pull_request", %{"action" => "closed", "pull_request" => pr}) do
    if pr["merged"] do
      process_merged_pr(pr)
    else
      {:skip, "PR closed without merging"}
    end
  end

  defp process_event("pull_request", %{"action" => action}) do
    {:skip, "PR action '#{action}' not handled"}
  end

  # Process release events
  defp process_event("release", %{"action" => "published", "release" => release, "repository" => repo}) do
    process_release(release, repo)
  end

  defp process_event("release", %{"action" => action}) do
    {:skip, "Release action '#{action}' not handled"}
  end

  # Ping event (GitHub sends this when webhook is first set up)
  defp process_event("ping", %{"zen" => zen}) do
    Logger.info("GitHub webhook ping: #{zen}")
    {:ok, %{message: "pong", zen: zen}}
  end

  defp process_event(event_type, _params) do
    {:skip, "Event type '#{event_type}' not handled"}
  end

  defp process_merged_pr(pr) do
    # Check for marketing-relevant labels
    labels = Enum.map(pr["labels"] || [], & &1["name"])

    if should_generate_content?(labels) do
      feature_info = %{
        type: :pull_request,
        title: pr["title"],
        body: pr["body"] || "",
        url: pr["html_url"],
        repo: pr["base"]["repo"]["full_name"],
        author: pr["user"]["login"],
        labels: labels,
        merged_at: pr["merged_at"]
      }

      ContentGenerator.generate_from_github_event(feature_info)
    else
      {:skip, "No marketing label found"}
    end
  end

  defp process_release(release, repo) do
    feature_info = %{
      type: :release,
      title: release["name"] || release["tag_name"],
      body: release["body"] || "",
      url: release["html_url"],
      repo: repo["full_name"],
      author: release["author"]["login"],
      tag: release["tag_name"],
      prerelease: release["prerelease"]
    }

    # Always generate content for releases (unless prerelease)
    if release["prerelease"] do
      {:skip, "Prerelease, skipping"}
    else
      ContentGenerator.generate_from_github_event(feature_info)
    end
  end

  # Only generate content if PR has specific labels
  defp should_generate_content?(labels) do
    marketing_labels = ["marketing", "feature", "announcement", "blog-worthy"]
    Enum.any?(labels, &(&1 in marketing_labels))
  end
end
