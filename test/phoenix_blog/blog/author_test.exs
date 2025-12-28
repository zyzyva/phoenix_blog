defmodule PhoenixBlog.Blog.AuthorTest do
  use PhoenixBlog.DataCase, async: true

  alias PhoenixBlog.Blog.Author

  describe "changeset/2" do
    test "valid with required fields" do
      attrs = %{name: "John Doe", email: "john@example.com"}
      changeset = Author.changeset(%Author{}, attrs)
      assert changeset.valid?
    end

    test "invalid without name" do
      attrs = %{email: "john@example.com"}
      changeset = Author.changeset(%Author{}, attrs)
      refute changeset.valid?
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid without email" do
      attrs = %{name: "John Doe"}
      changeset = Author.changeset(%Author{}, attrs)
      refute changeset.valid?
      assert %{email: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates name minimum length" do
      attrs = %{name: "", email: "john@example.com"}
      changeset = Author.changeset(%Author{}, attrs)
      refute changeset.valid?
      assert %{name: [_]} = errors_on(changeset)
    end

    test "validates name maximum length" do
      long_name = String.duplicate("a", 101)
      attrs = %{name: long_name, email: "john@example.com"}
      changeset = Author.changeset(%Author{}, attrs)
      refute changeset.valid?
      assert %{name: [_]} = errors_on(changeset)
    end

    test "validates bio maximum length" do
      long_bio = String.duplicate("a", 501)
      attrs = %{name: "John", email: "john@example.com", bio: long_bio}
      changeset = Author.changeset(%Author{}, attrs)
      refute changeset.valid?
      assert %{bio: [_]} = errors_on(changeset)
    end

    test "valid with all optional fields" do
      attrs = %{
        name: "John Doe",
        email: "john@example.com",
        avatar_url: "https://example.com/avatar.jpg",
        bio: "A prolific writer",
        external_id: "user_123"
      }

      changeset = Author.changeset(%Author{}, attrs)
      assert changeset.valid?
    end
  end
end
