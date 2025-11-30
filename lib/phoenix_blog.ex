defmodule PhoenixBlog do
  @moduledoc """
  PhoenixBlog - A blog engine for Phoenix applications.

  ## Features

  - Blog post management with markdown support
  - AI-powered content generation (Claude API)
  - AI-powered image generation (Google Imagen)
  - SEO keyword research and tracking
  - Feature screenshot management
  - Cloud storage integration (S3/R2)

  ## Configuration

  Configure in your application:

      config :phoenix_blog,
        # Storage configuration (required for image uploads)
        storage: [
          bucket: "your-bucket",
          public_url: "https://your-cdn.example.com"
        ],

        # AI Content Generation (optional)
        anthropic_api_key: System.get_env("ANTHROPIC_API_KEY"),
        anthropic_model: "claude-sonnet-4-5-20250929",

        # AI Image Generation (optional)
        google_cloud_project: System.get_env("GOOGLE_CLOUD_PROJECT"),
        google_cloud_location: "us-central1",
        imagen_model: "imagen-4.0-generate-001",

        # Features file path (optional)
        features_file: "priv/content/features.json"

  ## Usage

  The main contexts are:

  - `PhoenixBlog.Blog` - Blog posts and images
  - `PhoenixBlog.Keywords` - Keyword research data
  - `PhoenixBlog.Content.Features` - Product feature definitions
  - `PhoenixBlog.Content.FeatureScreenshots` - Feature screenshots
  - `PhoenixBlog.AI.ClaudeClient` - AI content generation
  - `PhoenixBlog.AI.ImagenClient` - AI image generation
  """
end
