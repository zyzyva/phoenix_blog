defmodule PhoenixBlog.CostsTest do
  use PhoenixBlog.DataCase, async: true

  alias PhoenixBlog.Costs
  import PhoenixBlog.Fixtures

  describe "record_cost/1" do
    test "creates a cost entry with valid attrs" do
      author = author_fixture()

      attrs = %{
        service: "huggingface",
        operation: "text_to_image",
        cost: Decimal.new("0.05"),
        user_id: author.id
      }

      assert {:ok, entry} = Costs.record_cost(attrs)
      assert entry.service == "huggingface"
      assert entry.operation == "text_to_image"
      assert Decimal.equal?(entry.cost, Decimal.new("0.05"))
    end

    test "returns error with invalid attrs" do
      assert {:error, changeset} = Costs.record_cost(%{})
      assert %{service: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "record_text_generation/7" do
    test "records text generation with tokens" do
      author = author_fixture()

      assert {:ok, entry} =
               Costs.record_text_generation(
                 author.id,
                 "claude",
                 "generate_content",
                 1000,
                 500,
                 Decimal.new("0.0225"),
                 request_id: "req_123",
                 metadata: %{"model" => "claude-3-sonnet"}
               )

      assert entry.service == "claude"
      assert entry.operation == "generate_content"
      assert entry.input_tokens == 1000
      assert entry.output_tokens == 500
      assert entry.request_id == "req_123"
      assert entry.metadata["model"] == "claude-3-sonnet"
    end
  end

  describe "record_media_generation/6" do
    test "records media generation with units" do
      author = author_fixture()

      assert {:ok, entry} =
               Costs.record_media_generation(
                 author.id,
                 "huggingface",
                 "text_to_image",
                 Decimal.new("1"),
                 Decimal.new("0.03"),
                 request_id: "gen_456"
               )

      assert entry.service == "huggingface"
      assert entry.operation == "text_to_image"
      assert Decimal.equal?(entry.units, Decimal.new("1"))
      assert entry.request_id == "gen_456"
    end
  end

  describe "record_scrape/5" do
    test "records scraping operation" do
      author = author_fixture()

      assert {:ok, entry} =
               Costs.record_scrape(
                 author.id,
                 "apify",
                 "facebook_posts",
                 Decimal.new("0.10"),
                 metadata: %{"actor" => "facebook-scraper"}
               )

      assert entry.service == "apify"
      assert entry.operation == "facebook_posts"
      assert Decimal.equal?(entry.cost, Decimal.new("0.10"))
      assert entry.metadata["actor"] == "facebook-scraper"
    end
  end

  describe "total_cost/3" do
    test "returns sum of all costs for user" do
      author = author_fixture()
      cost_entry_fixture(author: author, cost: Decimal.new("0.10"))
      cost_entry_fixture(author: author, cost: Decimal.new("0.25"))
      cost_entry_fixture(author: author, cost: Decimal.new("0.15"))

      total = Costs.total_cost(author.id)
      assert Decimal.equal?(total, Decimal.new("0.50"))
    end

    test "returns zero when no costs" do
      author = author_fixture()
      total = Costs.total_cost(author.id)
      assert Decimal.equal?(total, Decimal.new("0"))
    end

    test "does not include costs from other users" do
      author1 = author_fixture()
      author2 = author_fixture()
      cost_entry_fixture(author: author1, cost: Decimal.new("0.10"))
      cost_entry_fixture(author: author2, cost: Decimal.new("0.50"))

      total = Costs.total_cost(author1.id)
      assert Decimal.equal?(total, Decimal.new("0.10"))
    end

    test "filters by date range" do
      author = author_fixture()
      cost_entry_fixture(author: author, cost: Decimal.new("0.10"))

      today = Date.utc_today()
      yesterday = Date.add(today, -1)
      tomorrow = Date.add(today, 1)

      total = Costs.total_cost(author.id, today, today)
      assert Decimal.equal?(total, Decimal.new("0.10"))

      total_yesterday = Costs.total_cost(author.id, yesterday, yesterday)
      assert Decimal.equal?(total_yesterday, Decimal.new("0"))

      total_future = Costs.total_cost(author.id, tomorrow, tomorrow)
      assert Decimal.equal?(total_future, Decimal.new("0"))
    end
  end

  describe "total_cost_this_month/1" do
    test "returns sum of costs for current month" do
      author = author_fixture()
      cost_entry_fixture(author: author, cost: Decimal.new("0.10"))
      cost_entry_fixture(author: author, cost: Decimal.new("0.20"))

      total = Costs.total_cost_this_month(author.id)
      assert Decimal.equal?(total, Decimal.new("0.30"))
    end
  end

  describe "cost_by_service/3" do
    test "returns costs grouped by service" do
      author = author_fixture()
      cost_entry_fixture(author: author, service: "huggingface", cost: Decimal.new("0.10"))
      cost_entry_fixture(author: author, service: "huggingface", cost: Decimal.new("0.05"))
      cost_entry_fixture(author: author, service: "claude", cost: Decimal.new("0.20"))

      result = Costs.cost_by_service(author.id)

      assert Decimal.equal?(result["huggingface"], Decimal.new("0.15"))
      assert Decimal.equal?(result["claude"], Decimal.new("0.20"))
    end

    test "returns empty map when no costs" do
      author = author_fixture()
      assert Costs.cost_by_service(author.id) == %{}
    end
  end

  describe "cost_by_operation/4" do
    test "returns costs grouped by operation for a service" do
      author = author_fixture()
      cost_entry_fixture(author: author, service: "huggingface", operation: "text_to_image", cost: Decimal.new("0.10"))
      cost_entry_fixture(author: author, service: "huggingface", operation: "text_to_image", cost: Decimal.new("0.05"))
      cost_entry_fixture(author: author, service: "huggingface", operation: "text_to_video", cost: Decimal.new("0.50"))

      result = Costs.cost_by_operation(author.id, "huggingface")

      text_to_image = Enum.find(result, &(&1.operation == "text_to_image"))
      text_to_video = Enum.find(result, &(&1.operation == "text_to_video"))

      assert Decimal.equal?(text_to_image.cost, Decimal.new("0.15"))
      assert text_to_image.count == 2
      assert Decimal.equal?(text_to_video.cost, Decimal.new("0.50"))
      assert text_to_video.count == 1
    end
  end

  describe "daily_costs/2" do
    test "returns daily costs map" do
      author = author_fixture()
      cost_entry_fixture(author: author, cost: Decimal.new("0.10"))
      cost_entry_fixture(author: author, cost: Decimal.new("0.20"))

      result = Costs.daily_costs(author.id)

      today = Date.utc_today()
      assert Map.has_key?(result, today)
      assert Decimal.equal?(result[today], Decimal.new("0.30"))
    end
  end

  describe "recent_entries/2" do
    test "returns recent cost entries limited by count" do
      author = author_fixture()
      _entry1 = cost_entry_fixture(author: author, operation: "op1")
      _entry2 = cost_entry_fixture(author: author, operation: "op2")
      _entry3 = cost_entry_fixture(author: author, operation: "op3")

      result = Costs.recent_entries(author.id, 2)

      assert length(result) == 2
    end

    test "returns all entries when limit exceeds count" do
      author = author_fixture()
      cost_entry_fixture(author: author, operation: "op1")
      cost_entry_fixture(author: author, operation: "op2")
      cost_entry_fixture(author: author, operation: "op3")

      result = Costs.recent_entries(author.id, 100)

      assert length(result) == 3
    end

    test "returns empty list when no entries" do
      author = author_fixture()
      assert Costs.recent_entries(author.id) == []
    end
  end

  describe "token_usage/3" do
    test "returns token usage stats" do
      author = author_fixture()
      cost_entry_fixture(author: author, input_tokens: 1000, output_tokens: 500, cost: Decimal.new("0.02"))
      cost_entry_fixture(author: author, input_tokens: 2000, output_tokens: 1000, cost: Decimal.new("0.04"))

      result = Costs.token_usage(author.id)

      assert result.total_input == 3000
      assert result.total_output == 1500
      assert Decimal.equal?(result.total_cost, Decimal.new("0.06"))
    end

    test "excludes entries without tokens" do
      author = author_fixture()
      cost_entry_fixture(author: author, input_tokens: 1000, output_tokens: 500, cost: Decimal.new("0.02"))
      cost_entry_fixture(author: author, cost: Decimal.new("0.10"))

      result = Costs.token_usage(author.id)

      assert result.total_input == 1000
      assert result.total_output == 500
    end
  end

  describe "budget_exceeded?/2" do
    test "returns true when costs exceed budget" do
      author = author_fixture()
      cost_entry_fixture(author: author, cost: Decimal.new("15.00"))

      assert Costs.budget_exceeded?(author.id, "10.00")
    end

    test "returns false when costs are under budget" do
      author = author_fixture()
      cost_entry_fixture(author: author, cost: Decimal.new("5.00"))

      refute Costs.budget_exceeded?(author.id, "10.00")
    end

    test "returns true when costs equal budget" do
      author = author_fixture()
      cost_entry_fixture(author: author, cost: Decimal.new("10.00"))

      assert Costs.budget_exceeded?(author.id, "10.00")
    end
  end

  describe "services/0" do
    test "returns available services" do
      assert Costs.services() == ~w(apify huggingface claude gemini replicate meta_ads openai anthropic)
    end
  end
end
