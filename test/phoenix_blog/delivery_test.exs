defmodule PhoenixBlog.DeliveryTest do
  use PhoenixBlog.DataCase, async: true

  import PhoenixBlog.Fixtures

  alias PhoenixBlog.Delivery
  alias PhoenixBlog.Delivery.Webhook

  describe "list_webhooks/2" do
    test "returns all webhooks for a user ordered by name" do
      author = author_fixture()
      author2 = author_fixture()

      {:ok, beta} = Delivery.create_webhook(webhook_attrs(author, name: "Beta Hook"))
      {:ok, alpha} = Delivery.create_webhook(webhook_attrs(author, name: "Alpha Hook"))
      {:ok, _other} = Delivery.create_webhook(webhook_attrs(author2, name: "Other"))

      webhooks = Delivery.list_webhooks(author.id)
      assert length(webhooks) == 2
      assert hd(webhooks).id == alpha.id
      assert List.last(webhooks).id == beta.id
    end

    test "filters by status" do
      author = author_fixture()

      {:ok, active} = Delivery.create_webhook(webhook_attrs(author))
      {:ok, paused} = Delivery.create_webhook(webhook_attrs(author, name: "Paused", status: "paused"))

      actives = Delivery.list_webhooks(author.id, status: "active")
      assert length(actives) == 1
      assert hd(actives).id == active.id

      pauseds = Delivery.list_webhooks(author.id, status: "paused")
      assert length(pauseds) == 1
      assert hd(pauseds).id == paused.id
    end
  end

  describe "list_active_webhooks/1" do
    test "returns only active webhooks" do
      author = author_fixture()

      {:ok, active} = Delivery.create_webhook(webhook_attrs(author))
      {:ok, _paused} = Delivery.create_webhook(webhook_attrs(author, name: "Paused", status: "paused"))

      actives = Delivery.list_active_webhooks(author.id)
      assert length(actives) == 1
      assert hd(actives).id == active.id
    end
  end

  describe "list_webhooks_for_event/2" do
    test "returns active webhooks subscribed to event" do
      author = author_fixture()

      {:ok, subscribed} = Delivery.create_webhook(webhook_attrs(author))
      {:ok, _not_subscribed} = Delivery.create_webhook(webhook_attrs(author, name: "Other", events: ["insight.created"]))
      {:ok, _paused} = Delivery.create_webhook(webhook_attrs(author, name: "Paused", status: "paused"))

      webhooks = Delivery.list_webhooks_for_event(author.id, "generation.completed")
      assert length(webhooks) == 1
      assert hd(webhooks).id == subscribed.id
    end

    test "returns empty list when no webhooks match" do
      author = author_fixture()

      {:ok, _} = Delivery.create_webhook(webhook_attrs(author))
      webhooks = Delivery.list_webhooks_for_event(author.id, "research.completed")
      assert webhooks == []
    end
  end

  describe "get_webhook!/1" do
    test "returns the webhook with given id" do
      author = author_fixture()
      {:ok, webhook} = Delivery.create_webhook(webhook_attrs(author))
      fetched = Delivery.get_webhook!(webhook.id)
      assert fetched.id == webhook.id
      assert fetched.name == webhook.name
    end

    test "raises if webhook not found" do
      assert_raise Ecto.NoResultsError, fn ->
        Delivery.get_webhook!(0)
      end
    end
  end

  describe "get_webhook!/2" do
    test "returns the webhook scoped to user" do
      author = author_fixture()
      {:ok, webhook} = Delivery.create_webhook(webhook_attrs(author))
      fetched = Delivery.get_webhook!(author.id, webhook.id)
      assert fetched.id == webhook.id
    end

    test "raises if webhook belongs to different user" do
      author = author_fixture()
      {:ok, webhook} = Delivery.create_webhook(webhook_attrs(author))
      assert_raise Ecto.NoResultsError, fn ->
        Delivery.get_webhook!(0, webhook.id)
      end
    end
  end

  describe "create_webhook/1" do
    test "creates webhook with valid attrs and auto-generates secret" do
      author = author_fixture()
      assert {:ok, webhook} = Delivery.create_webhook(webhook_attrs(author))
      assert webhook.user_id == author.id
      assert webhook.name == "Content Webhook"
      assert webhook.url == "https://example.com/webhook"
      assert webhook.events == ["generation.completed", "generation.failed"]
      assert webhook.status == "active"
      assert webhook.secret != nil
      assert byte_size(webhook.secret) == 32
    end

    test "preserves provided secret" do
      author = author_fixture()
      custom_secret = :crypto.strong_rand_bytes(32)
      attrs = webhook_attrs(author, secret: custom_secret)
      assert {:ok, webhook} = Delivery.create_webhook(attrs)
      assert webhook.secret == custom_secret
    end

    test "preserves provided secret as string key" do
      author = author_fixture()
      custom_secret = :crypto.strong_rand_bytes(32)
      # Use all string keys
      attrs = %{
        "user_id" => author.id,
        "name" => "Content Webhook",
        "url" => "https://example.com/webhook",
        "events" => ["generation.completed", "generation.failed"],
        "status" => "active",
        "secret" => custom_secret
      }
      assert {:ok, webhook} = Delivery.create_webhook(attrs)
      assert webhook.secret == custom_secret
    end

    test "fails with invalid attrs" do
      assert {:error, changeset} = Delivery.create_webhook(%{})
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "update_webhook/2" do
    test "updates webhook with valid attrs" do
      author = author_fixture()
      {:ok, webhook} = Delivery.create_webhook(webhook_attrs(author))
      assert {:ok, updated} = Delivery.update_webhook(webhook, %{name: "Updated Name"})
      assert updated.name == "Updated Name"
    end

    test "fails with invalid url" do
      author = author_fixture()
      {:ok, webhook} = Delivery.create_webhook(webhook_attrs(author))
      assert {:error, changeset} = Delivery.update_webhook(webhook, %{url: "not-a-url"})
      assert %{url: ["must be a valid HTTP/HTTPS URL"]} = errors_on(changeset)
    end
  end

  describe "pause_webhook/1" do
    test "sets status to paused" do
      author = author_fixture()
      {:ok, webhook} = Delivery.create_webhook(webhook_attrs(author))
      assert webhook.status == "active"

      assert {:ok, paused} = Delivery.pause_webhook(webhook)
      assert paused.status == "paused"
    end
  end

  describe "activate_webhook/1" do
    test "sets status to active" do
      author = author_fixture()
      {:ok, webhook} = Delivery.create_webhook(webhook_attrs(author, status: "paused"))
      assert {:ok, activated} = Delivery.activate_webhook(webhook)
      assert activated.status == "active"
    end
  end

  describe "record_success/1" do
    test "updates last_triggered_at and resets failure_count" do
      author = author_fixture()
      {:ok, webhook} = Delivery.create_webhook(webhook_attrs(author))

      assert {:ok, success} = Delivery.record_success(webhook)
      assert not is_nil(success.last_triggered_at)
      assert success.failure_count == 0
      assert is_nil(success.last_error)
    end

    test "clears previous errors" do
      author = author_fixture()
      {:ok, webhook} = Delivery.create_webhook(webhook_attrs(author))
      {:ok, failed} = Delivery.record_failure(webhook, "Some error")
      assert failed.failure_count == 1

      {:ok, success} = Delivery.record_success(failed)
      assert success.failure_count == 0
      assert is_nil(success.last_error)
    end
  end

  describe "record_failure/2" do
    test "increments failure_count and sets error" do
      author = author_fixture()
      {:ok, webhook} = Delivery.create_webhook(webhook_attrs(author))
      assert webhook.failure_count == 0

      assert {:ok, failed} = Delivery.record_failure(webhook, "Connection timeout")
      assert failed.failure_count == 1
      assert failed.last_error == "Connection timeout"
      assert not is_nil(failed.last_triggered_at)
    end

    test "accumulates failure count" do
      author = author_fixture()
      {:ok, webhook} = Delivery.create_webhook(webhook_attrs(author))

      {:ok, failed1} = Delivery.record_failure(webhook, "Error 1")
      assert failed1.failure_count == 1

      {:ok, failed2} = Delivery.record_failure(failed1, "Error 2")
      assert failed2.failure_count == 2
      assert failed2.last_error == "Error 2"
    end
  end

  describe "regenerate_secret/1" do
    test "generates a new secret" do
      author = author_fixture()
      {:ok, webhook} = Delivery.create_webhook(webhook_attrs(author))
      original_secret = webhook.secret

      assert {:ok, regenerated} = Delivery.regenerate_secret(webhook)
      assert regenerated.secret != original_secret
      assert byte_size(regenerated.secret) == 32
    end
  end

  describe "delete_webhook/1" do
    test "deletes the webhook" do
      author = author_fixture()
      {:ok, webhook} = Delivery.create_webhook(webhook_attrs(author))
      assert {:ok, _} = Delivery.delete_webhook(webhook)
      assert_raise Ecto.NoResultsError, fn ->
        Delivery.get_webhook!(webhook.id)
      end
    end
  end

  describe "change_webhook/2" do
    test "returns a changeset" do
      author = author_fixture()
      {:ok, webhook} = Delivery.create_webhook(webhook_attrs(author))
      changeset = Delivery.change_webhook(webhook)
      assert %Ecto.Changeset{} = changeset
    end

    test "returns changeset with changes" do
      author = author_fixture()
      {:ok, webhook} = Delivery.create_webhook(webhook_attrs(author))
      changeset = Delivery.change_webhook(webhook, %{name: "New name"})
      assert changeset.changes == %{name: "New name"}
    end
  end

  describe "count_by_status/1" do
    test "returns counts grouped by status" do
      author = author_fixture()
      Delivery.create_webhook(webhook_attrs(author))
      Delivery.create_webhook(webhook_attrs(author, name: "Active 2"))
      Delivery.create_webhook(webhook_attrs(author, name: "Paused", status: "paused"))

      counts = Delivery.count_by_status(author.id)
      assert counts["active"] == 2
      assert counts["paused"] == 1
    end

    test "returns empty map for user with no webhooks" do
      assert Delivery.count_by_status(0) == %{}
    end
  end

  describe "list_failing_webhooks/1" do
    test "returns webhooks with failures ordered by failure_count desc" do
      author = author_fixture()
      {:ok, w1} = Delivery.create_webhook(webhook_attrs(author))
      {:ok, w2} = Delivery.create_webhook(webhook_attrs(author, name: "Second"))
      {:ok, _healthy} = Delivery.create_webhook(webhook_attrs(author, name: "Healthy"))

      {:ok, w1_failed} = Delivery.record_failure(w1, "Error")
      {:ok, w2_failed} = Delivery.record_failure(w2, "Error")
      {:ok, w2_failed2} = Delivery.record_failure(w2_failed, "Error again")

      failing = Delivery.list_failing_webhooks(author.id)
      assert length(failing) == 2
      assert hd(failing).id == w2_failed2.id
      assert hd(failing).failure_count == 2
      # Verify we only have one entry for w1
      w1_entries = Enum.filter(failing, &(&1.id == w1_failed.id))
      assert length(w1_entries) == 1
    end

    test "excludes webhooks with zero failures" do
      author = author_fixture()
      {:ok, _healthy} = Delivery.create_webhook(webhook_attrs(author))
      failing = Delivery.list_failing_webhooks(author.id)
      assert failing == []
    end
  end

  describe "sign_payload/2" do
    test "signs payload with webhook secret" do
      author = author_fixture()
      {:ok, webhook} = Delivery.create_webhook(webhook_attrs(author))
      payload = ~s({"event": "test"})

      signature = Delivery.sign_payload(webhook, payload)

      expected = Webhook.sign_payload(webhook.secret, payload)
      assert signature == expected
    end

    test "produces consistent signatures" do
      author = author_fixture()
      {:ok, webhook} = Delivery.create_webhook(webhook_attrs(author))
      payload = ~s({"event": "test"})

      sig1 = Delivery.sign_payload(webhook, payload)
      sig2 = Delivery.sign_payload(webhook, payload)
      assert sig1 == sig2
    end

    test "different payloads produce different signatures" do
      author = author_fixture()
      {:ok, webhook} = Delivery.create_webhook(webhook_attrs(author))

      sig1 = Delivery.sign_payload(webhook, ~s({"event": "one"}))
      sig2 = Delivery.sign_payload(webhook, ~s({"event": "two"}))
      assert sig1 != sig2
    end
  end

  # Helper to build webhook attrs with an author
  defp webhook_attrs(author, overrides \\ []) do
    Enum.into(overrides, %{
      user_id: author.id,
      name: "Content Webhook",
      url: "https://example.com/webhook",
      events: ["generation.completed", "generation.failed"],
      status: "active"
    })
  end
end
