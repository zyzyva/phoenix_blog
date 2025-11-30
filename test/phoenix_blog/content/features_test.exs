defmodule PhoenixBlog.Content.FeaturesTest do
  use PhoenixBlog.DataCase, async: true

  import ExUnit.CaptureLog

  alias PhoenixBlog.Content.FeatureScreenshot
  alias PhoenixBlog.Content.Features
  alias PhoenixBlog.Repo

  # The features.json file contains an "example_feature" by default

  setup do
    # Clear the cached features before each test
    :persistent_term.erase({PhoenixBlog.Content.Features, :features})
    :ok
  end

  describe "all/0" do
    test "returns all features from JSON file" do
      features = Features.all()
      assert is_map(features)
      assert Map.has_key?(features, "example_feature")
    end

    test "caches features in persistent_term" do
      # First call loads from file
      features1 = Features.all()
      # Second call should return same data from cache
      features2 = Features.all()
      assert features1 == features2
    end
  end

  describe "options/0" do
    test "returns list of {name, key, label} tuples" do
      options = Features.options()
      assert is_list(options)
      assert {name, key, label} = hd(options)
      assert is_binary(name)
      assert is_binary(key)
      assert is_binary(label)
    end

    test "includes example feature" do
      options = Features.options()

      assert Enum.any?(options, fn {name, key, _label} ->
               key == "example_feature" and name == "Example Feature"
             end)
    end
  end

  describe "get/1" do
    test "returns feature by key" do
      feature = Features.get("example_feature")
      assert feature["name"] == "Example Feature"
      assert feature["pricing"] == "Free"
      assert is_list(feature["use_cases"])
    end

    test "returns nil for nonexistent key" do
      assert Features.get("nonexistent_feature") == nil
    end
  end

  describe "format_for_prompt/1" do
    test "formats feature details for AI prompt" do
      prompt = Features.format_for_prompt("example_feature")
      assert is_binary(prompt)
      assert prompt =~ "Example Feature"
      assert prompt =~ "https://example.com"
      assert prompt =~ "Free"
      assert prompt =~ "Example use case 1"
      assert prompt =~ "Try it free"
    end

    test "returns nil for nonexistent feature" do
      assert Features.format_for_prompt("nonexistent") == nil
    end

    test "includes url_note when present" do
      # The example feature has url_note: null, so we test that it doesn't break
      prompt = Features.format_for_prompt("example_feature")
      # Should not have "(null)" in the output
      refute prompt =~ "(null)"
    end

    test "includes screenshots when present" do
      # Create a screenshot for the example feature
      %FeatureScreenshot{}
      |> FeatureScreenshot.changeset(%{
        feature_key: "example_feature",
        url: "https://cdn.example.com/screenshot.jpg",
        storage_key: "blog/images/feature-screenshots/example_feature/test.jpg",
        alt_text: "Example screenshot",
        caption: "Step 1 caption",
        step_description: "First step"
      })
      |> Repo.insert!()

      prompt = Features.format_for_prompt("example_feature")
      assert prompt =~ "SCREENSHOTS"
      assert prompt =~ "Example screenshot"
      assert prompt =~ "Step 1"
    end
  end

  describe "format_many_for_prompt/1" do
    test "formats multiple features" do
      prompts = Features.format_many_for_prompt(["example_feature"])
      assert length(prompts) == 1
      assert hd(prompts) =~ "Example Feature"
    end

    test "filters out nonexistent features" do
      prompts = Features.format_many_for_prompt(["example_feature", "nonexistent"])
      assert length(prompts) == 1
    end

    test "returns empty list for non-list input" do
      assert Features.format_many_for_prompt(nil) == []
      assert Features.format_many_for_prompt("not_a_list") == []
    end
  end

  describe "reload/0" do
    test "clears cache and reloads features" do
      # Load features first
      _features = Features.all()

      # Reload
      reloaded = Features.reload()

      # Should still have the same data
      assert is_map(reloaded)
      assert Map.has_key?(reloaded, "example_feature")
    end
  end

  describe "error handling" do
    test "handles missing features file gracefully" do
      # Temporarily set an invalid path
      original = Application.get_env(:phoenix_blog, :features_file)
      Application.put_env(:phoenix_blog, :features_file, "priv/content/nonexistent.json")
      :persistent_term.erase({PhoenixBlog.Content.Features, :features})

      log =
        capture_log(fn ->
          features = Features.all()
          assert features == %{}
        end)

      assert log =~ "Failed to read features.json"

      # Restore original config
      if original do
        Application.put_env(:phoenix_blog, :features_file, original)
      else
        Application.delete_env(:phoenix_blog, :features_file)
      end
    end
  end
end
