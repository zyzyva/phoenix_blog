defmodule PhoenixBlog.Delivery.WebhookTest do
  use PhoenixBlog.DataCase, async: true

  alias PhoenixBlog.Delivery.Webhook
  import PhoenixBlog.Fixtures

  describe "changeset/2" do
    setup do
      %{author: author_fixture()}
    end

    test "valid with required fields", %{author: author} do
      attrs = %{
        name: "My Webhook",
        url: "https://example.com/webhook",
        secret: :crypto.strong_rand_bytes(32),
        user_id: author.id
      }

      changeset = Webhook.changeset(%Webhook{}, attrs)
      assert changeset.valid?
    end

    test "invalid without name", %{author: author} do
      attrs = %{url: "https://example.com/webhook", secret: <<1, 2, 3>>, user_id: author.id}
      changeset = Webhook.changeset(%Webhook{}, attrs)
      refute changeset.valid?
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid without url", %{author: author} do
      attrs = %{name: "My Webhook", secret: <<1, 2, 3>>, user_id: author.id}
      changeset = Webhook.changeset(%Webhook{}, attrs)
      refute changeset.valid?
      assert %{url: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid without secret", %{author: author} do
      attrs = %{name: "My Webhook", url: "https://example.com/webhook", user_id: author.id}
      changeset = Webhook.changeset(%Webhook{}, attrs)
      refute changeset.valid?
      assert %{secret: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid without user_id" do
      attrs = %{name: "My Webhook", url: "https://example.com/webhook", secret: <<1, 2, 3>>}
      changeset = Webhook.changeset(%Webhook{}, attrs)
      refute changeset.valid?
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates status inclusion", %{author: author} do
      attrs = %{
        name: "My Webhook",
        url: "https://example.com/webhook",
        secret: <<1, 2, 3>>,
        user_id: author.id,
        status: "invalid"
      }

      changeset = Webhook.changeset(%Webhook{}, attrs)
      refute changeset.valid?
      assert %{status: ["is invalid"]} = errors_on(changeset)
    end

    test "accepts all valid statuses", %{author: author} do
      for status <- ~w(active paused disabled) do
        attrs = %{
          name: "My Webhook",
          url: "https://example.com/webhook",
          secret: <<1, 2, 3>>,
          user_id: author.id,
          status: status
        }

        changeset = Webhook.changeset(%Webhook{}, attrs)
        assert changeset.valid?, "Expected status #{status} to be valid"
      end
    end

    test "validates URL format - rejects invalid URLs", %{author: author} do
      for invalid_url <- ["not-a-url", "ftp://example.com", "example.com"] do
        attrs = %{
          name: "My Webhook",
          url: invalid_url,
          secret: <<1, 2, 3>>,
          user_id: author.id
        }

        changeset = Webhook.changeset(%Webhook{}, attrs)
        refute changeset.valid?, "Expected #{invalid_url} to be invalid"
        assert %{url: [_]} = errors_on(changeset)
      end
    end

    test "validates URL format - accepts valid HTTP/HTTPS URLs", %{author: author} do
      for valid_url <- ["http://example.com", "https://example.com/webhook", "https://api.example.com:8080/hook"] do
        attrs = %{
          name: "My Webhook",
          url: valid_url,
          secret: <<1, 2, 3>>,
          user_id: author.id
        }

        changeset = Webhook.changeset(%Webhook{}, attrs)
        assert changeset.valid?, "Expected #{valid_url} to be valid"
      end
    end

    test "validates events - rejects invalid events", %{author: author} do
      attrs = %{
        name: "My Webhook",
        url: "https://example.com/webhook",
        secret: <<1, 2, 3>>,
        user_id: author.id,
        events: ["invalid.event", "generation.completed"]
      }

      changeset = Webhook.changeset(%Webhook{}, attrs)
      refute changeset.valid?
      assert %{events: [msg]} = errors_on(changeset)
      assert msg =~ "invalid.event"
    end

    test "validates events - accepts all valid events", %{author: author} do
      attrs = %{
        name: "My Webhook",
        url: "https://example.com/webhook",
        secret: <<1, 2, 3>>,
        user_id: author.id,
        events: ~w(generation.completed generation.failed insight.created research.completed)
      }

      changeset = Webhook.changeset(%Webhook{}, attrs)
      assert changeset.valid?
    end

    test "defaults status to active", %{author: author} do
      attrs = %{
        name: "My Webhook",
        url: "https://example.com/webhook",
        secret: <<1, 2, 3>>,
        user_id: author.id
      }

      changeset = Webhook.changeset(%Webhook{}, attrs)
      webhook = Ecto.Changeset.apply_changes(changeset)
      assert webhook.status == "active"
    end

    test "defaults to empty events and zero failure_count", %{author: author} do
      attrs = %{
        name: "My Webhook",
        url: "https://example.com/webhook",
        secret: <<1, 2, 3>>,
        user_id: author.id
      }

      changeset = Webhook.changeset(%Webhook{}, attrs)
      webhook = Ecto.Changeset.apply_changes(changeset)
      assert webhook.events == []
      assert webhook.failure_count == 0
    end
  end

  describe "trigger_changeset/3 on success" do
    test "resets failure_count and clears last_error" do
      webhook = %Webhook{failure_count: 3, last_error: "Previous error", status: "active"}
      changeset = Webhook.trigger_changeset(webhook, true)

      assert Ecto.Changeset.get_change(changeset, :last_triggered_at)
      assert Ecto.Changeset.get_change(changeset, :failure_count) == 0
      assert Ecto.Changeset.get_change(changeset, :last_error) == nil
    end
  end

  describe "trigger_changeset/3 on failure" do
    test "increments failure_count and sets last_error" do
      webhook = %Webhook{failure_count: 0, status: "active"}
      changeset = Webhook.trigger_changeset(webhook, false, "Connection timeout")

      assert Ecto.Changeset.get_change(changeset, :last_triggered_at)
      assert Ecto.Changeset.get_change(changeset, :failure_count) == 1
      assert Ecto.Changeset.get_change(changeset, :last_error) == "Connection timeout"
    end

    test "disables webhook after 5 failures" do
      webhook = %Webhook{failure_count: 4, status: "active"}
      changeset = Webhook.trigger_changeset(webhook, false, "Connection timeout")

      assert Ecto.Changeset.get_change(changeset, :failure_count) == 5
      assert Ecto.Changeset.get_change(changeset, :status) == "disabled"
    end

    test "keeps status when under 5 failures" do
      webhook = %Webhook{failure_count: 3, status: "active"}
      changeset = Webhook.trigger_changeset(webhook, false, "Connection timeout")

      assert Ecto.Changeset.get_change(changeset, :failure_count) == 4
      refute Ecto.Changeset.get_change(changeset, :status)
    end
  end

  describe "status_values/0" do
    test "returns valid status values" do
      assert Webhook.status_values() == ~w(active paused disabled)
    end
  end

  describe "event_types/0" do
    test "returns valid event types" do
      assert Webhook.event_types() == ~w(generation.completed generation.failed insight.created research.completed)
    end
  end

  describe "active?/1" do
    test "returns true for active webhook" do
      assert Webhook.active?(%Webhook{status: "active"})
    end

    test "returns false for paused webhook" do
      refute Webhook.active?(%Webhook{status: "paused"})
    end

    test "returns false for disabled webhook" do
      refute Webhook.active?(%Webhook{status: "disabled"})
    end
  end

  describe "subscribes_to?/2" do
    test "returns true when event is in events list" do
      webhook = %Webhook{events: ["generation.completed", "insight.created"]}
      assert Webhook.subscribes_to?(webhook, "generation.completed")
      assert Webhook.subscribes_to?(webhook, "insight.created")
    end

    test "returns false when event is not in events list" do
      webhook = %Webhook{events: ["generation.completed"]}
      refute Webhook.subscribes_to?(webhook, "insight.created")
    end

    test "returns false for empty events list" do
      webhook = %Webhook{events: []}
      refute Webhook.subscribes_to?(webhook, "generation.completed")
    end
  end

  describe "generate_secret/0" do
    test "generates 32-byte random secret" do
      secret = Webhook.generate_secret()
      assert byte_size(secret) == 32
    end

    test "generates unique secrets" do
      secret1 = Webhook.generate_secret()
      secret2 = Webhook.generate_secret()
      refute secret1 == secret2
    end
  end

  describe "sign_payload/2" do
    test "generates HMAC-SHA256 signature" do
      secret = <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16>>
      payload = ~s({"event":"test"})

      signature = Webhook.sign_payload(secret, payload)

      assert is_binary(signature)
      assert String.length(signature) == 64
      assert signature =~ ~r/^[a-f0-9]+$/
    end

    test "produces consistent signatures for same input" do
      secret = Webhook.generate_secret()
      payload = ~s({"event":"test","data":{}})

      sig1 = Webhook.sign_payload(secret, payload)
      sig2 = Webhook.sign_payload(secret, payload)

      assert sig1 == sig2
    end

    test "produces different signatures for different secrets" do
      secret1 = Webhook.generate_secret()
      secret2 = Webhook.generate_secret()
      payload = ~s({"event":"test"})

      sig1 = Webhook.sign_payload(secret1, payload)
      sig2 = Webhook.sign_payload(secret2, payload)

      refute sig1 == sig2
    end

    test "produces different signatures for different payloads" do
      secret = Webhook.generate_secret()
      payload1 = ~s({"event":"test1"})
      payload2 = ~s({"event":"test2"})

      sig1 = Webhook.sign_payload(secret, payload1)
      sig2 = Webhook.sign_payload(secret, payload2)

      refute sig1 == sig2
    end
  end
end
