defmodule PhoenixBlog.Costs.CostEntryTest do
  use PhoenixBlog.DataCase, async: true

  alias PhoenixBlog.Costs.CostEntry
  import PhoenixBlog.Fixtures

  describe "changeset/2" do
    setup do
      %{author: author_fixture()}
    end

    test "valid with required fields", %{author: author} do
      attrs = %{
        service: "huggingface",
        operation: "text_to_image",
        cost: Decimal.new("0.05"),
        user_id: author.id
      }

      changeset = CostEntry.changeset(%CostEntry{}, attrs)
      assert changeset.valid?
    end

    test "invalid without service", %{author: author} do
      attrs = %{operation: "text_to_image", cost: Decimal.new("0.05"), user_id: author.id}
      changeset = CostEntry.changeset(%CostEntry{}, attrs)
      refute changeset.valid?
      assert %{service: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid without operation", %{author: author} do
      attrs = %{service: "huggingface", cost: Decimal.new("0.05"), user_id: author.id}
      changeset = CostEntry.changeset(%CostEntry{}, attrs)
      refute changeset.valid?
      assert %{operation: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid without cost", %{author: author} do
      attrs = %{service: "huggingface", operation: "text_to_image", user_id: author.id}
      changeset = CostEntry.changeset(%CostEntry{}, attrs)
      refute changeset.valid?
      assert %{cost: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid without user_id" do
      attrs = %{service: "huggingface", operation: "text_to_image", cost: Decimal.new("0.05")}
      changeset = CostEntry.changeset(%CostEntry{}, attrs)
      refute changeset.valid?
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates service inclusion", %{author: author} do
      attrs = %{service: "invalid_service", operation: "test", cost: Decimal.new("0.05"), user_id: author.id}
      changeset = CostEntry.changeset(%CostEntry{}, attrs)
      refute changeset.valid?
      assert %{service: ["is invalid"]} = errors_on(changeset)
    end

    test "accepts all valid services", %{author: author} do
      for service <- ~w(apify huggingface claude gemini replicate meta_ads openai anthropic) do
        attrs = %{service: service, operation: "test", cost: Decimal.new("0.01"), user_id: author.id}
        changeset = CostEntry.changeset(%CostEntry{}, attrs)
        assert changeset.valid?, "Expected service #{service} to be valid"
      end
    end

    test "validates cost is non-negative", %{author: author} do
      attrs = %{service: "huggingface", operation: "test", cost: Decimal.new("-0.01"), user_id: author.id}
      changeset = CostEntry.changeset(%CostEntry{}, attrs)
      refute changeset.valid?
      assert %{cost: [_]} = errors_on(changeset)
    end

    test "accepts zero cost", %{author: author} do
      attrs = %{service: "huggingface", operation: "test", cost: Decimal.new("0"), user_id: author.id}
      changeset = CostEntry.changeset(%CostEntry{}, attrs)
      assert changeset.valid?
    end

    test "valid with all optional fields", %{author: author} do
      attrs = %{
        service: "claude",
        operation: "generate_content",
        input_tokens: 1000,
        output_tokens: 500,
        units: Decimal.new("1.5"),
        cost: Decimal.new("0.0225"),
        request_id: "req_abc123",
        metadata: %{"model" => "claude-3-sonnet", "purpose" => "blog_post"},
        user_id: author.id
      }

      changeset = CostEntry.changeset(%CostEntry{}, attrs)
      assert changeset.valid?
    end

    test "defaults metadata to empty map", %{author: author} do
      attrs = %{service: "huggingface", operation: "test", cost: Decimal.new("0.01"), user_id: author.id}
      changeset = CostEntry.changeset(%CostEntry{}, attrs)
      entry = Ecto.Changeset.apply_changes(changeset)
      assert entry.metadata == %{}
    end
  end

  describe "services/0" do
    test "returns valid services" do
      assert CostEntry.services() == ~w(apify huggingface claude gemini replicate meta_ads openai anthropic)
    end
  end

  describe "total_tokens/1" do
    test "returns sum of input and output tokens" do
      entry = %CostEntry{input_tokens: 1000, output_tokens: 500}
      assert CostEntry.total_tokens(entry) == 1500
    end

    test "handles nil input_tokens" do
      entry = %CostEntry{input_tokens: nil, output_tokens: 500}
      assert CostEntry.total_tokens(entry) == 500
    end

    test "handles nil output_tokens" do
      entry = %CostEntry{input_tokens: 1000, output_tokens: nil}
      assert CostEntry.total_tokens(entry) == 1000
    end

    test "handles both nil" do
      entry = %CostEntry{input_tokens: nil, output_tokens: nil}
      assert CostEntry.total_tokens(entry) == 0
    end

    test "handles zero tokens" do
      entry = %CostEntry{input_tokens: 0, output_tokens: 0}
      assert CostEntry.total_tokens(entry) == 0
    end
  end
end
