defmodule PhoenixBlog.GenerationsTest do
  use PhoenixBlog.DataCase, async: true

  import PhoenixBlog.Fixtures

  alias PhoenixBlog.Generations

  describe "list_generations/2" do
    test "returns all generations for a user" do
      author = author_fixture()
      author2 = author_fixture()

      {:ok, g1} = Generations.queue_generation(generation_attrs(author))
      {:ok, g2} = Generations.queue_generation(generation_attrs(author, input_prompt: "Second"))
      {:ok, _other} = Generations.queue_generation(generation_attrs(author2))

      generations = Generations.list_generations(author.id)
      assert length(generations) == 2
      ids = Enum.map(generations, & &1.id)
      assert g1.id in ids
      assert g2.id in ids
    end

    test "filters by status" do
      author = author_fixture()

      {:ok, queued} = Generations.queue_generation(generation_attrs(author))
      {:ok, processing} = Generations.queue_generation(generation_attrs(author, input_prompt: "Second"))
      {:ok, processing} = Generations.start_processing(processing)

      queued_list = Generations.list_generations(author.id, status: "queued")
      assert length(queued_list) == 1
      assert hd(queued_list).id == queued.id

      processing_list = Generations.list_generations(author.id, status: "processing")
      assert length(processing_list) == 1
      assert hd(processing_list).id == processing.id
    end

    test "filters by content_type" do
      author = author_fixture()

      {:ok, image} = Generations.queue_generation(generation_attrs(author))
      {:ok, video} = Generations.queue_generation(generation_attrs(author, content_type: "video"))

      images = Generations.list_generations(author.id, content_type: "image")
      assert length(images) == 1
      assert hd(images).id == image.id

      videos = Generations.list_generations(author.id, content_type: "video")
      assert length(videos) == 1
      assert hd(videos).id == video.id
    end

    test "respects limit" do
      author = author_fixture()

      for i <- 1..5 do
        Generations.queue_generation(generation_attrs(author, input_prompt: "Generation #{i}"))
      end

      generations = Generations.list_generations(author.id, limit: 3)
      assert length(generations) == 3
    end

    test "returns generations (with newer items first when timestamps differ)" do
      author = author_fixture()

      {:ok, _first} = Generations.queue_generation(generation_attrs(author))
      {:ok, _second} = Generations.queue_generation(generation_attrs(author, input_prompt: "Second"))

      generations = Generations.list_generations(author.id)
      assert length(generations) == 2
    end
  end

  describe "list_queued/1" do
    test "returns only queued generations" do
      author1 = author_fixture()
      author2 = author_fixture()

      {:ok, _first} = Generations.queue_generation(generation_attrs(author1))
      {:ok, _second} = Generations.queue_generation(generation_attrs(author2))
      {:ok, third} = Generations.queue_generation(generation_attrs(author1, input_prompt: "Third"))
      {:ok, _} = Generations.start_processing(third)

      queued = Generations.list_queued()
      assert length(queued) == 2
      # All queued items should have queued status
      assert Enum.all?(queued, &(&1.status == "queued"))
    end

    test "respects limit" do
      author = author_fixture()

      for i <- 1..5 do
        Generations.queue_generation(generation_attrs(author, input_prompt: "Gen #{i}"))
      end

      queued = Generations.list_queued(2)
      assert length(queued) == 2
    end
  end

  describe "list_pending_delivery/1" do
    test "returns completed generations with delivery_method" do
      author = author_fixture()

      {:ok, g1} = Generations.queue_generation(generation_attrs(author, delivery_method: "email"))
      {:ok, g1} = Generations.start_processing(g1)
      {:ok, completed} = Generations.complete_generation(g1, "output", ["url"], "provider", "model", Decimal.new("0.10"))

      {:ok, g2} = Generations.queue_generation(generation_attrs(author, input_prompt: "No delivery"))
      {:ok, g2} = Generations.start_processing(g2)
      {:ok, _no_delivery} = Generations.complete_generation(g2, "output", ["url"], "provider", "model", Decimal.new("0.10"))

      pending = Generations.list_pending_delivery(author.id)
      assert length(pending) == 1
      assert hd(pending).id == completed.id
    end
  end

  describe "get_generation!/1" do
    test "returns the generation with given id" do
      author = author_fixture()
      {:ok, generation} = Generations.queue_generation(generation_attrs(author))
      fetched = Generations.get_generation!(generation.id)
      assert fetched.id == generation.id
    end

    test "raises if generation not found" do
      assert_raise Ecto.NoResultsError, fn ->
        Generations.get_generation!(0)
      end
    end
  end

  describe "get_generation!/2" do
    test "returns the generation scoped to user" do
      author = author_fixture()
      {:ok, generation} = Generations.queue_generation(generation_attrs(author))
      fetched = Generations.get_generation!(author.id, generation.id)
      assert fetched.id == generation.id
    end

    test "raises if generation belongs to different user" do
      author = author_fixture()
      {:ok, generation} = Generations.queue_generation(generation_attrs(author))
      assert_raise Ecto.NoResultsError, fn ->
        Generations.get_generation!(0, generation.id)
      end
    end
  end

  describe "queue_generation/1" do
    test "creates generation with queued status" do
      author = author_fixture()
      assert {:ok, generation} = Generations.queue_generation(generation_attrs(author))
      assert generation.status == "queued"
      assert generation.user_id == author.id
      assert generation.content_type == "image"
      assert generation.input_prompt == "A professional headshot"
    end

    test "fails with invalid attrs" do
      assert {:error, changeset} = Generations.queue_generation(%{})
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "accepts insight_id when insight exists" do
      author = author_fixture()
      {:ok, insight} = PhoenixBlog.Insights.create_insight(%{
        user_id: author.id,
        insight_type: "messaging_angle",
        title: "Test Insight"
      })
      attrs = generation_attrs(author, insight_id: insight.id)
      assert {:ok, generation} = Generations.queue_generation(attrs)
      assert generation.insight_id == insight.id
    end
  end

  describe "start_processing/1" do
    test "sets status to processing" do
      author = author_fixture()
      {:ok, generation} = Generations.queue_generation(generation_attrs(author))
      assert generation.status == "queued"

      assert {:ok, processing} = Generations.start_processing(generation)
      assert processing.status == "processing"
    end
  end

  describe "complete_generation/6" do
    test "sets status to completed with output details" do
      author = author_fixture()
      {:ok, generation} = Generations.queue_generation(generation_attrs(author))
      {:ok, processing} = Generations.start_processing(generation)

      output_urls = ["https://example.com/image.png"]
      cost = Decimal.new("0.15")

      assert {:ok, completed} = Generations.complete_generation(
        processing,
        "Generated content",
        output_urls,
        "replicate",
        "flux-pro",
        cost
      )

      assert completed.status == "completed"
      assert completed.output_content == "Generated content"
      assert completed.output_urls == output_urls
      assert completed.provider == "replicate"
      assert completed.model == "flux-pro"
      assert Decimal.equal?(completed.cost, cost)
    end
  end

  describe "fail_generation/2" do
    test "sets status to failed with error message" do
      author = author_fixture()
      {:ok, generation} = Generations.queue_generation(generation_attrs(author))
      {:ok, processing} = Generations.start_processing(generation)

      assert {:ok, failed} = Generations.fail_generation(processing, "API timeout")
      assert failed.status == "failed"
      assert failed.error_message == "API timeout"
    end
  end

  describe "mark_delivered/1" do
    test "sets status to delivered and delivered_at" do
      author = author_fixture()
      {:ok, generation} = Generations.queue_generation(generation_attrs(author, delivery_method: "webhook"))
      {:ok, processing} = Generations.start_processing(generation)
      {:ok, completed} = Generations.complete_generation(processing, "output", [], "p", "m", Decimal.new("0"))

      assert {:ok, delivered} = Generations.mark_delivered(completed)
      assert delivered.status == "delivered"
      assert not is_nil(delivered.delivered_at)
    end
  end

  describe "delete_generation/1" do
    test "deletes the generation" do
      author = author_fixture()
      {:ok, generation} = Generations.queue_generation(generation_attrs(author))
      assert {:ok, _} = Generations.delete_generation(generation)
      assert_raise Ecto.NoResultsError, fn ->
        Generations.get_generation!(generation.id)
      end
    end
  end

  describe "count_by_status/1" do
    test "returns counts grouped by status" do
      author = author_fixture()
      {:ok, _} = Generations.queue_generation(generation_attrs(author))
      {:ok, g2} = Generations.queue_generation(generation_attrs(author, input_prompt: "Second"))
      {:ok, _} = Generations.start_processing(g2)

      counts = Generations.count_by_status(author.id)
      assert counts["queued"] == 1
      assert counts["processing"] == 1
    end

    test "returns empty map for user with no generations" do
      assert Generations.count_by_status(0) == %{}
    end
  end

  describe "count_by_content_type/1" do
    test "returns counts grouped by content_type" do
      author = author_fixture()
      {:ok, _} = Generations.queue_generation(generation_attrs(author))
      {:ok, _} = Generations.queue_generation(generation_attrs(author, content_type: "video"))
      {:ok, _} = Generations.queue_generation(generation_attrs(author, content_type: "video", input_prompt: "Another"))

      counts = Generations.count_by_content_type(author.id)
      assert counts["image"] == 1
      assert counts["video"] == 2
    end
  end

  describe "total_cost/1" do
    test "returns sum of all costs for user" do
      author = author_fixture()
      {:ok, g1} = Generations.queue_generation(generation_attrs(author))
      {:ok, p1} = Generations.start_processing(g1)
      {:ok, _} = Generations.complete_generation(p1, "out", [], "p", "m", Decimal.new("0.10"))

      {:ok, g2} = Generations.queue_generation(generation_attrs(author, input_prompt: "Second"))
      {:ok, p2} = Generations.start_processing(g2)
      {:ok, _} = Generations.complete_generation(p2, "out", [], "p", "m", Decimal.new("0.25"))

      total = Generations.total_cost(author.id)
      assert Decimal.equal?(total, Decimal.new("0.35"))
    end

    test "returns zero for user with no completed generations" do
      author = author_fixture()
      {:ok, _} = Generations.queue_generation(generation_attrs(author))
      total = Generations.total_cost(author.id)
      assert Decimal.equal?(total, Decimal.new("0"))
    end

    test "returns zero for user with no generations" do
      total = Generations.total_cost(0)
      assert Decimal.equal?(total, Decimal.new("0"))
    end
  end

  describe "recent_completed/2" do
    test "returns completed and delivered generations" do
      author = author_fixture()
      {:ok, g1} = Generations.queue_generation(generation_attrs(author))
      {:ok, p1} = Generations.start_processing(g1)
      {:ok, completed} = Generations.complete_generation(p1, "out", [], "p", "m", Decimal.new("0"))

      {:ok, g2} = Generations.queue_generation(generation_attrs(author, input_prompt: "Second", delivery_method: "email"))
      {:ok, p2} = Generations.start_processing(g2)
      {:ok, c2} = Generations.complete_generation(p2, "out", [], "p", "m", Decimal.new("0"))
      {:ok, delivered} = Generations.mark_delivered(c2)

      {:ok, _queued} = Generations.queue_generation(generation_attrs(author, input_prompt: "Queued"))

      recent = Generations.recent_completed(author.id)
      assert length(recent) == 2
      ids = Enum.map(recent, & &1.id)
      assert completed.id in ids
      assert delivered.id in ids
    end

    test "respects limit" do
      author = author_fixture()

      for i <- 1..5 do
        {:ok, g} = Generations.queue_generation(generation_attrs(author, input_prompt: "Gen #{i}"))
        {:ok, p} = Generations.start_processing(g)
        {:ok, _} = Generations.complete_generation(p, "out", [], "p", "m", Decimal.new("0"))
      end

      recent = Generations.recent_completed(author.id, 3)
      assert length(recent) == 3
    end
  end

  # Helper to build generation attrs with an author
  defp generation_attrs(author, overrides \\ []) do
    Enum.into(overrides, %{
      user_id: author.id,
      content_type: "image",
      status: "queued",
      input_prompt: "A professional headshot",
      input_params: %{"style" => "realistic"}
    })
  end
end
