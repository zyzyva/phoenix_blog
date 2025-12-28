defmodule PhoenixBlog.Social.AccountTest do
  use PhoenixBlog.DataCase, async: true

  alias PhoenixBlog.Social.Account
  import PhoenixBlog.Fixtures

  describe "changeset/2" do
    setup do
      %{author: author_fixture()}
    end

    test "valid with required fields", %{author: author} do
      attrs = %{
        platform: "twitter",
        platform_user_id: "123456",
        access_token: <<1, 2, 3, 4>>,
        user_id: author.id
      }

      changeset = Account.changeset(%Account{}, attrs)
      assert changeset.valid?
    end

    test "invalid without platform", %{author: author} do
      attrs = %{platform_user_id: "123", access_token: <<1, 2, 3>>, user_id: author.id}
      changeset = Account.changeset(%Account{}, attrs)
      refute changeset.valid?
      assert %{platform: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid without platform_user_id", %{author: author} do
      attrs = %{platform: "twitter", access_token: <<1, 2, 3>>, user_id: author.id}
      changeset = Account.changeset(%Account{}, attrs)
      refute changeset.valid?
      assert %{platform_user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid without access_token", %{author: author} do
      attrs = %{platform: "twitter", platform_user_id: "123", user_id: author.id}
      changeset = Account.changeset(%Account{}, attrs)
      refute changeset.valid?
      assert %{access_token: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid without user_id" do
      attrs = %{platform: "twitter", platform_user_id: "123", access_token: <<1, 2, 3>>}
      changeset = Account.changeset(%Account{}, attrs)
      refute changeset.valid?
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates platform inclusion", %{author: author} do
      attrs = %{platform: "invalid", platform_user_id: "123", access_token: <<1, 2, 3>>, user_id: author.id}
      changeset = Account.changeset(%Account{}, attrs)
      refute changeset.valid?
      assert %{platform: ["is invalid"]} = errors_on(changeset)
    end

    test "accepts all valid platforms", %{author: author} do
      for platform <- ~w(twitter linkedin reddit facebook instagram) do
        attrs = %{platform: platform, platform_user_id: "id_#{platform}", access_token: <<1, 2, 3>>, user_id: author.id}
        changeset = Account.changeset(%Account{}, attrs)
        assert changeset.valid?, "Expected platform #{platform} to be valid"
      end
    end

    test "validates status inclusion", %{author: author} do
      attrs = %{
        platform: "twitter",
        platform_user_id: "123",
        access_token: <<1, 2, 3>>,
        user_id: author.id,
        status: "invalid"
      }

      changeset = Account.changeset(%Account{}, attrs)
      refute changeset.valid?
      assert %{status: ["is invalid"]} = errors_on(changeset)
    end

    test "accepts all valid statuses", %{author: author} do
      for status <- ~w(active expired revoked) do
        attrs = %{
          platform: "twitter",
          platform_user_id: "id_#{status}",
          access_token: <<1, 2, 3>>,
          user_id: author.id,
          status: status
        }

        changeset = Account.changeset(%Account{}, attrs)
        assert changeset.valid?, "Expected status #{status} to be valid"
      end
    end

    test "valid with all optional fields", %{author: author} do
      attrs = %{
        platform: "twitter",
        platform_user_id: "123456",
        platform_username: "testuser",
        access_token: :crypto.strong_rand_bytes(32),
        refresh_token: :crypto.strong_rand_bytes(32),
        token_expires_at: DateTime.utc_now() |> DateTime.add(3600, :second),
        scopes: ["read", "write"],
        status: "active",
        metadata: %{"profile_image" => "https://example.com/image.jpg"},
        user_id: author.id
      }

      changeset = Account.changeset(%Account{}, attrs)
      assert changeset.valid?
    end

    test "defaults status to active", %{author: author} do
      attrs = %{platform: "twitter", platform_user_id: "123", access_token: <<1, 2, 3>>, user_id: author.id}
      changeset = Account.changeset(%Account{}, attrs)
      account = Ecto.Changeset.apply_changes(changeset)
      assert account.status == "active"
    end

    test "defaults to empty arrays and maps", %{author: author} do
      attrs = %{platform: "twitter", platform_user_id: "123", access_token: <<1, 2, 3>>, user_id: author.id}
      changeset = Account.changeset(%Account{}, attrs)
      account = Ecto.Changeset.apply_changes(changeset)
      assert account.scopes == []
      assert account.metadata == %{}
    end
  end

  describe "token_changeset/2" do
    test "updates tokens" do
      account = %Account{access_token: <<1, 2, 3>>, status: "active"}
      new_token = <<4, 5, 6>>
      new_refresh = <<7, 8, 9>>
      expires = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second)

      changeset =
        Account.token_changeset(account, %{
          access_token: new_token,
          refresh_token: new_refresh,
          token_expires_at: expires
        })

      assert Ecto.Changeset.get_change(changeset, :access_token) == new_token
      assert Ecto.Changeset.get_change(changeset, :refresh_token) == new_refresh
      assert Ecto.Changeset.get_change(changeset, :token_expires_at) == expires
    end

    test "can update status" do
      account = %Account{access_token: <<1, 2, 3>>, status: "active"}
      changeset = Account.token_changeset(account, %{access_token: <<4, 5, 6>>, status: "expired"})
      assert Ecto.Changeset.get_change(changeset, :status) == "expired"
    end

    test "valid when existing access_token present" do
      # validate_required checks the final value, not just changes
      account = %Account{access_token: <<1, 2, 3>>}
      changeset = Account.token_changeset(account, %{status: "expired"})
      assert changeset.valid?
    end

    test "invalid when access_token is nil" do
      account = %Account{access_token: nil}
      changeset = Account.token_changeset(account, %{status: "expired"})
      refute changeset.valid?
      assert %{access_token: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "platforms/0" do
    test "returns valid platforms" do
      assert Account.platforms() == ~w(twitter linkedin reddit facebook instagram)
    end
  end

  describe "status_values/0" do
    test "returns valid status values" do
      assert Account.status_values() == ~w(active expired revoked)
    end
  end

  describe "token_expired?/1" do
    test "returns false when token_expires_at is nil" do
      account = %Account{token_expires_at: nil}
      refute Account.token_expired?(account)
    end

    test "returns true when token has expired" do
      past = DateTime.utc_now() |> DateTime.add(-3600, :second)
      account = %Account{token_expires_at: past}
      assert Account.token_expired?(account)
    end

    test "returns false when token has not expired" do
      future = DateTime.utc_now() |> DateTime.add(3600, :second)
      account = %Account{token_expires_at: future}
      refute Account.token_expired?(account)
    end
  end
end
