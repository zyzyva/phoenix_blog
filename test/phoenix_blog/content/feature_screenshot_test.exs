defmodule PhoenixBlog.Content.FeatureScreenshotTest do
  use PhoenixBlog.DataCase, async: true

  alias PhoenixBlog.Content.FeatureScreenshot

  describe "changeset/2" do
    @valid_attrs %{
      feature_key: "qr_generator",
      url: "https://cdn.example.com/screenshots/qr-step1.jpg",
      storage_key: "blog/images/feature-screenshots/qr_generator/2024/01/abc123-step1.jpg"
    }

    test "valid with required fields" do
      changeset = FeatureScreenshot.changeset(%FeatureScreenshot{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid without feature_key" do
      attrs = Map.delete(@valid_attrs, :feature_key)
      changeset = FeatureScreenshot.changeset(%FeatureScreenshot{}, attrs)
      refute changeset.valid?
      assert %{feature_key: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid without url" do
      attrs = Map.delete(@valid_attrs, :url)
      changeset = FeatureScreenshot.changeset(%FeatureScreenshot{}, attrs)
      refute changeset.valid?
      assert %{url: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid without storage_key" do
      attrs = Map.delete(@valid_attrs, :storage_key)
      changeset = FeatureScreenshot.changeset(%FeatureScreenshot{}, attrs)
      refute changeset.valid?
      assert %{storage_key: ["can't be blank"]} = errors_on(changeset)
    end

    test "valid with optional fields" do
      attrs =
        Map.merge(@valid_attrs, %{
          position: 1,
          alt_text: "Screenshot showing QR code generator",
          caption: "Step 1: Enter your URL",
          step_description: "Enter URL"
        })

      changeset = FeatureScreenshot.changeset(%FeatureScreenshot{}, attrs)
      assert changeset.valid?
    end

    test "validates alt_text max length" do
      attrs = Map.put(@valid_attrs, :alt_text, String.duplicate("a", 256))
      changeset = FeatureScreenshot.changeset(%FeatureScreenshot{}, attrs)
      refute changeset.valid?
      assert %{alt_text: ["should be at most 255 character(s)"]} = errors_on(changeset)
    end

    test "validates caption max length" do
      attrs = Map.put(@valid_attrs, :caption, String.duplicate("a", 501))
      changeset = FeatureScreenshot.changeset(%FeatureScreenshot{}, attrs)
      refute changeset.valid?
      assert %{caption: ["should be at most 500 character(s)"]} = errors_on(changeset)
    end

    test "validates step_description max length" do
      attrs = Map.put(@valid_attrs, :step_description, String.duplicate("a", 201))
      changeset = FeatureScreenshot.changeset(%FeatureScreenshot{}, attrs)
      refute changeset.valid?
      assert %{step_description: ["should be at most 200 character(s)"]} = errors_on(changeset)
    end

    test "defaults position to 0" do
      changeset = FeatureScreenshot.changeset(%FeatureScreenshot{}, @valid_attrs)
      screenshot = Ecto.Changeset.apply_changes(changeset)
      assert screenshot.position == 0
    end
  end
end
