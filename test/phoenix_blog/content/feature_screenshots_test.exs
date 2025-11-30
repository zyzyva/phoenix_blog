defmodule PhoenixBlog.Content.FeatureScreenshotsTest do
  use PhoenixBlog.DataCase, async: true

  alias PhoenixBlog.Content.FeatureScreenshot
  alias PhoenixBlog.Content.FeatureScreenshots
  alias PhoenixBlog.Repo

  # Helper to create a screenshot directly in DB (bypasses S3 upload)
  defp create_test_screenshot(feature_key, attrs \\ %{}) do
    base_attrs = %{
      feature_key: feature_key,
      url: "https://cdn.example.com/screenshots/#{feature_key}/test.jpg",
      storage_key: "blog/images/feature-screenshots/#{feature_key}/2024/01/abc123-test.jpg",
      position: attrs[:position] || 0,
      alt_text: attrs[:alt_text] || "Test screenshot"
    }

    %FeatureScreenshot{}
    |> FeatureScreenshot.changeset(Map.merge(base_attrs, attrs))
    |> Repo.insert!()
  end

  describe "list_screenshots/1" do
    test "returns screenshots for a feature ordered by position" do
      create_test_screenshot("qr_generator", %{position: 2})
      create_test_screenshot("qr_generator", %{position: 0})
      create_test_screenshot("qr_generator", %{position: 1})
      create_test_screenshot("other_feature", %{position: 0})

      screenshots = FeatureScreenshots.list_screenshots("qr_generator")
      assert length(screenshots) == 3
      assert Enum.map(screenshots, & &1.position) == [0, 1, 2]
    end

    test "returns empty list for feature with no screenshots" do
      assert FeatureScreenshots.list_screenshots("nonexistent") == []
    end
  end

  describe "list_screenshots_by_features/1" do
    test "returns screenshots grouped by feature key" do
      create_test_screenshot("qr_generator", %{position: 0})
      create_test_screenshot("qr_generator", %{position: 1})
      create_test_screenshot("card_scanner", %{position: 0})

      result = FeatureScreenshots.list_screenshots_by_features(["qr_generator", "card_scanner"])

      assert length(result["qr_generator"]) == 2
      assert length(result["card_scanner"]) == 1
    end

    test "returns empty map for empty list" do
      result = FeatureScreenshots.list_screenshots_by_features([])
      assert result == %{}
    end
  end

  describe "list_all_screenshots/0" do
    test "returns all screenshots grouped by feature" do
      create_test_screenshot("qr_generator", %{position: 0})
      create_test_screenshot("card_scanner", %{position: 0})
      create_test_screenshot("card_scanner", %{position: 1})

      result = FeatureScreenshots.list_all_screenshots()

      assert length(result["qr_generator"]) == 1
      assert length(result["card_scanner"]) == 2
    end
  end

  describe "get_screenshot/1" do
    test "returns screenshot by ID" do
      screenshot = create_test_screenshot("qr_generator")
      assert FeatureScreenshots.get_screenshot(screenshot.id).id == screenshot.id
    end

    test "returns nil for nonexistent ID" do
      assert FeatureScreenshots.get_screenshot(-1) == nil
    end
  end

  describe "get_screenshot!/1" do
    test "returns screenshot by ID" do
      screenshot = create_test_screenshot("qr_generator")
      assert FeatureScreenshots.get_screenshot!(screenshot.id).id == screenshot.id
    end

    test "raises for nonexistent ID" do
      assert_raise Ecto.NoResultsError, fn ->
        FeatureScreenshots.get_screenshot!(-1)
      end
    end
  end

  describe "update_screenshot/2" do
    test "updates screenshot metadata" do
      screenshot = create_test_screenshot("qr_generator", %{alt_text: "Original"})

      {:ok, updated} =
        FeatureScreenshots.update_screenshot(screenshot, %{alt_text: "Updated alt text"})

      assert updated.alt_text == "Updated alt text"
    end

    test "validates updated attributes" do
      screenshot = create_test_screenshot("qr_generator")

      {:error, changeset} =
        FeatureScreenshots.update_screenshot(screenshot, %{alt_text: String.duplicate("a", 256)})

      assert %{alt_text: ["should be at most 255 character(s)"]} = errors_on(changeset)
    end
  end

  describe "reorder_screenshots/2" do
    test "reorders screenshots by ID list" do
      s1 = create_test_screenshot("qr_generator", %{position: 0})
      s2 = create_test_screenshot("qr_generator", %{position: 1})
      s3 = create_test_screenshot("qr_generator", %{position: 2})

      # Reverse order
      {:ok, _} = FeatureScreenshots.reorder_screenshots("qr_generator", [s3.id, s2.id, s1.id])

      screenshots = FeatureScreenshots.list_screenshots("qr_generator")
      assert Enum.map(screenshots, & &1.id) == [s3.id, s2.id, s1.id]
      assert Enum.map(screenshots, & &1.position) == [0, 1, 2]
    end
  end

  describe "move_screenshot/2" do
    test "moves screenshot down in position" do
      s1 = create_test_screenshot("qr_generator", %{position: 0})
      s2 = create_test_screenshot("qr_generator", %{position: 1})
      s3 = create_test_screenshot("qr_generator", %{position: 2})

      # Move s1 to position 2
      {:ok, _} = FeatureScreenshots.move_screenshot(s1, 2)

      screenshots = FeatureScreenshots.list_screenshots("qr_generator")
      positions = for s <- screenshots, do: {s.id, s.position}
      # s2 and s3 should shift up, s1 should be at 2
      assert {s1.id, 2} in positions
      assert {s2.id, 0} in positions
      assert {s3.id, 1} in positions
    end

    test "moves screenshot up in position" do
      s1 = create_test_screenshot("qr_generator", %{position: 0})
      s2 = create_test_screenshot("qr_generator", %{position: 1})
      s3 = create_test_screenshot("qr_generator", %{position: 2})

      # Move s3 to position 0
      {:ok, _} = FeatureScreenshots.move_screenshot(s3, 0)

      screenshots = FeatureScreenshots.list_screenshots("qr_generator")
      positions = for s <- screenshots, do: {s.id, s.position}
      # s1 and s2 should shift down, s3 should be at 0
      assert {s3.id, 0} in positions
      assert {s1.id, 1} in positions
      assert {s2.id, 2} in positions
    end

    test "no-op when moving to same position" do
      s1 = create_test_screenshot("qr_generator", %{position: 1})

      {:ok, result} = FeatureScreenshots.move_screenshot(s1, 1)
      assert result.position == 1
    end
  end

  describe "screenshot_counts/0" do
    test "returns count per feature" do
      create_test_screenshot("qr_generator")
      create_test_screenshot("qr_generator")
      create_test_screenshot("card_scanner")

      counts = FeatureScreenshots.screenshot_counts()
      assert counts["qr_generator"] == 2
      assert counts["card_scanner"] == 1
    end

    test "returns empty map when no screenshots" do
      assert FeatureScreenshots.screenshot_counts() == %{}
    end
  end
end
