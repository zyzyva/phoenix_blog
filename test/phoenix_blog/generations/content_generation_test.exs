defmodule PhoenixBlog.Generations.ContentGenerationTest do
  use PhoenixBlog.DataCase, async: true

  alias PhoenixBlog.Generations.ContentGeneration
  import PhoenixBlog.Fixtures

  describe "changeset/2" do
    setup do
      author = author_fixture()
      insight = insight_fixture(author: author)
      %{author: author, insight: insight}
    end

    test "valid with required fields", %{author: author} do
      attrs = %{content_type: "social_post", user_id: author.id}
      changeset = ContentGeneration.changeset(%ContentGeneration{}, attrs)
      assert changeset.valid?
    end

    test "invalid without content_type", %{author: author} do
      attrs = %{user_id: author.id}
      changeset = ContentGeneration.changeset(%ContentGeneration{}, attrs)
      refute changeset.valid?
      assert %{content_type: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid without user_id" do
      attrs = %{content_type: "social_post"}
      changeset = ContentGeneration.changeset(%ContentGeneration{}, attrs)
      refute changeset.valid?
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates content_type inclusion", %{author: author} do
      attrs = %{content_type: "invalid_type", user_id: author.id}
      changeset = ContentGeneration.changeset(%ContentGeneration{}, attrs)
      refute changeset.valid?
      assert %{content_type: ["is invalid"]} = errors_on(changeset)
    end

    test "accepts all valid content types", %{author: author} do
      for content_type <- ~w(social_post blog_post image video carousel) do
        attrs = %{content_type: content_type, user_id: author.id}
        changeset = ContentGeneration.changeset(%ContentGeneration{}, attrs)
        assert changeset.valid?, "Expected #{content_type} to be valid"
      end
    end

    test "validates status inclusion", %{author: author} do
      attrs = %{content_type: "social_post", user_id: author.id, status: "invalid"}
      changeset = ContentGeneration.changeset(%ContentGeneration{}, attrs)
      refute changeset.valid?
      assert %{status: ["is invalid"]} = errors_on(changeset)
    end

    test "accepts all valid statuses", %{author: author} do
      for status <- ~w(queued processing completed failed delivered) do
        attrs = %{content_type: "social_post", user_id: author.id, status: status}
        changeset = ContentGeneration.changeset(%ContentGeneration{}, attrs)
        assert changeset.valid?, "Expected status #{status} to be valid"
      end
    end

    test "validates delivery_method inclusion", %{author: author} do
      attrs = %{content_type: "social_post", user_id: author.id, delivery_method: "invalid"}
      changeset = ContentGeneration.changeset(%ContentGeneration{}, attrs)
      refute changeset.valid?
      assert %{delivery_method: ["is invalid"]} = errors_on(changeset)
    end

    test "accepts all valid delivery methods", %{author: author} do
      for delivery_method <- ~w(email webhook in_app) do
        attrs = %{content_type: "social_post", user_id: author.id, delivery_method: delivery_method}
        changeset = ContentGeneration.changeset(%ContentGeneration{}, attrs)
        assert changeset.valid?, "Expected delivery_method #{delivery_method} to be valid"
      end
    end

    test "accepts nil delivery_method", %{author: author} do
      attrs = %{content_type: "social_post", user_id: author.id, delivery_method: nil}
      changeset = ContentGeneration.changeset(%ContentGeneration{}, attrs)
      assert changeset.valid?
    end

    test "valid with insight", %{author: author, insight: insight} do
      attrs = %{content_type: "social_post", user_id: author.id, insight_id: insight.id}
      changeset = ContentGeneration.changeset(%ContentGeneration{}, attrs)
      assert changeset.valid?
    end

    test "valid with all optional fields", %{author: author, insight: insight} do
      attrs = %{
        content_type: "image",
        status: "processing",
        input_prompt: "Generate a product image",
        input_params: %{"style" => "photorealistic"},
        output_content: nil,
        output_urls: [],
        provider: "huggingface",
        model: "flux-1-dev",
        cost: Decimal.new("0.05"),
        delivery_method: "email",
        user_id: author.id,
        insight_id: insight.id
      }

      changeset = ContentGeneration.changeset(%ContentGeneration{}, attrs)
      assert changeset.valid?
    end

    test "defaults status to queued", %{author: author} do
      attrs = %{content_type: "social_post", user_id: author.id}
      changeset = ContentGeneration.changeset(%ContentGeneration{}, attrs)
      generation = Ecto.Changeset.apply_changes(changeset)
      assert generation.status == "queued"
    end

    test "defaults to empty arrays and maps", %{author: author} do
      attrs = %{content_type: "social_post", user_id: author.id}
      changeset = ContentGeneration.changeset(%ContentGeneration{}, attrs)
      generation = Ecto.Changeset.apply_changes(changeset)
      assert generation.output_urls == []
      assert generation.input_params == %{}
    end
  end

  describe "start_processing_changeset/1" do
    test "sets status to processing" do
      generation = %ContentGeneration{status: "queued"}
      changeset = ContentGeneration.start_processing_changeset(generation)
      assert Ecto.Changeset.get_change(changeset, :status) == "processing"
    end
  end

  describe "complete_changeset/6" do
    test "sets completed status with output data" do
      generation = %ContentGeneration{status: "processing"}
      output_content = "Generated content here"
      output_urls = ["https://example.com/image1.png"]
      provider = "huggingface"
      model = "flux-1-dev"
      cost = Decimal.new("0.05")

      changeset = ContentGeneration.complete_changeset(generation, output_content, output_urls, provider, model, cost)

      assert Ecto.Changeset.get_change(changeset, :status) == "completed"
      assert Ecto.Changeset.get_change(changeset, :output_content) == output_content
      assert Ecto.Changeset.get_change(changeset, :output_urls) == output_urls
      assert Ecto.Changeset.get_change(changeset, :provider) == provider
      assert Ecto.Changeset.get_change(changeset, :model) == model
      assert Ecto.Changeset.get_change(changeset, :cost) == cost
    end
  end

  describe "fail_changeset/2" do
    test "sets status to failed with error message" do
      generation = %ContentGeneration{status: "processing"}
      changeset = ContentGeneration.fail_changeset(generation, "API rate limited")

      assert Ecto.Changeset.get_change(changeset, :status) == "failed"
      assert Ecto.Changeset.get_change(changeset, :error_message) == "API rate limited"
    end
  end

  describe "deliver_changeset/1" do
    test "sets status to delivered with timestamp" do
      generation = %ContentGeneration{status: "completed"}
      changeset = ContentGeneration.deliver_changeset(generation)

      assert Ecto.Changeset.get_change(changeset, :status) == "delivered"
      assert Ecto.Changeset.get_change(changeset, :delivered_at)
    end
  end

  describe "content_types/0" do
    test "returns valid content types" do
      assert ContentGeneration.content_types() == ~w(social_post blog_post image video carousel)
    end
  end

  describe "status_values/0" do
    test "returns valid status values" do
      assert ContentGeneration.status_values() == ~w(queued processing completed failed delivered)
    end
  end

  describe "delivery_methods/0" do
    test "returns valid delivery methods" do
      assert ContentGeneration.delivery_methods() == ~w(email webhook in_app)
    end
  end

  describe "completed?/1" do
    test "returns true for completed generation" do
      assert ContentGeneration.completed?(%ContentGeneration{status: "completed"})
    end

    test "returns false for processing generation" do
      refute ContentGeneration.completed?(%ContentGeneration{status: "processing"})
    end

    test "returns false for queued generation" do
      refute ContentGeneration.completed?(%ContentGeneration{status: "queued"})
    end
  end

  describe "delivered?/1" do
    test "returns true for delivered generation" do
      assert ContentGeneration.delivered?(%ContentGeneration{status: "delivered"})
    end

    test "returns false for completed generation" do
      refute ContentGeneration.delivered?(%ContentGeneration{status: "completed"})
    end
  end

  describe "image?/1" do
    test "returns true for image content type" do
      assert ContentGeneration.image?(%ContentGeneration{content_type: "image"})
    end

    test "returns true for carousel content type" do
      assert ContentGeneration.image?(%ContentGeneration{content_type: "carousel"})
    end

    test "returns false for video content type" do
      refute ContentGeneration.image?(%ContentGeneration{content_type: "video"})
    end

    test "returns false for social_post content type" do
      refute ContentGeneration.image?(%ContentGeneration{content_type: "social_post"})
    end
  end

  describe "video?/1" do
    test "returns true for video content type" do
      assert ContentGeneration.video?(%ContentGeneration{content_type: "video"})
    end

    test "returns false for image content type" do
      refute ContentGeneration.video?(%ContentGeneration{content_type: "image"})
    end

    test "returns false for social_post content type" do
      refute ContentGeneration.video?(%ContentGeneration{content_type: "social_post"})
    end
  end
end
