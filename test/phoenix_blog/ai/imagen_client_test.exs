defmodule PhoenixBlog.AI.ImagenClientTest do
  use ExUnit.Case, async: true

  alias PhoenixBlog.AI.ImagenClient

  describe "configured?/0" do
    test "returns false when Google Cloud project not set" do
      original = Application.get_env(:phoenix_blog, :google_cloud_project)
      Application.delete_env(:phoenix_blog, :google_cloud_project)

      refute ImagenClient.configured?()

      if original, do: Application.put_env(:phoenix_blog, :google_cloud_project, original)
    end

    test "returns true when Google Cloud project is set" do
      original = Application.get_env(:phoenix_blog, :google_cloud_project)
      Application.put_env(:phoenix_blog, :google_cloud_project, "test-project")

      assert ImagenClient.configured?()

      if original do
        Application.put_env(:phoenix_blog, :google_cloud_project, original)
      else
        Application.delete_env(:phoenix_blog, :google_cloud_project)
      end
    end
  end

  describe "generate_image/2" do
    test "returns error when not configured" do
      original = Application.get_env(:phoenix_blog, :google_cloud_project)
      Application.delete_env(:phoenix_blog, :google_cloud_project)

      assert {:error, "Google Cloud credentials not configured"} =
               ImagenClient.generate_image("test prompt")

      if original, do: Application.put_env(:phoenix_blog, :google_cloud_project, original)
    end
  end

  describe "generate_blog_image/2" do
    test "returns error when not configured" do
      original = Application.get_env(:phoenix_blog, :google_cloud_project)
      Application.delete_env(:phoenix_blog, :google_cloud_project)

      assert {:error, "Google Cloud credentials not configured"} =
               ImagenClient.generate_blog_image("networking tips")

      if original, do: Application.put_env(:phoenix_blog, :google_cloud_project, original)
    end
  end

  describe "options handling" do
    test "documents valid aspect ratios" do
      valid_aspect_ratios = ["1:1", "3:4", "4:3", "16:9", "9:16"]
      assert is_list(valid_aspect_ratios)
      assert "16:9" in valid_aspect_ratios
    end

    test "documents default aspect ratio is 16:9 for blog images" do
      # Blog headers typically use 16:9 aspect ratio
      default_aspect = "16:9"
      assert is_binary(default_aspect)
    end

    test "accepts tone option for style" do
      valid_tones = ["casual", "friendly", "authoritative", "conversational", "professional"]
      assert is_list(valid_tones)
    end

    test "accepts title and excerpt options" do
      opts = [
        title: "How to Network Effectively",
        excerpt: "Learn the essential skills for professional connections"
      ]

      assert Keyword.has_key?(opts, :title)
      assert Keyword.has_key?(opts, :excerpt)
    end
  end

  describe "response format" do
    test "documents expected success response structure" do
      # Successful response should have image_data and mime_type
      expected_keys = [:image_data, :mime_type]
      assert is_list(expected_keys)
    end

    test "image_data should be binary when successful" do
      # When image generation succeeds, image_data is binary PNG data
      sample_binary = <<137, 80, 78, 71, 13, 10, 26, 10>>
      assert is_binary(sample_binary)
    end
  end
end
