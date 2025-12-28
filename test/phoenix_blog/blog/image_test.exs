defmodule PhoenixBlog.Blog.ImageTest do
  use PhoenixBlog.DataCase, async: true

  alias PhoenixBlog.Blog.Image
  import PhoenixBlog.Fixtures

  describe "changeset/2" do
    setup do
      %{author: author_fixture()}
    end

    test "valid with required fields", %{author: author} do
      attrs = %{
        filename: "image.jpg",
        storage_key: "uploads/image.jpg",
        url: "https://cdn.example.com/image.jpg",
        content_type: "image/jpeg",
        user_id: author.id
      }

      changeset = Image.changeset(%Image{}, attrs)
      assert changeset.valid?
    end

    test "invalid without filename", %{author: author} do
      attrs = %{
        storage_key: "uploads/image.jpg",
        url: "https://cdn.example.com/image.jpg",
        content_type: "image/jpeg",
        user_id: author.id
      }

      changeset = Image.changeset(%Image{}, attrs)
      refute changeset.valid?
      assert %{filename: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid without storage_key", %{author: author} do
      attrs = %{
        filename: "image.jpg",
        url: "https://cdn.example.com/image.jpg",
        content_type: "image/jpeg",
        user_id: author.id
      }

      changeset = Image.changeset(%Image{}, attrs)
      refute changeset.valid?
      assert %{storage_key: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid without url", %{author: author} do
      attrs = %{
        filename: "image.jpg",
        storage_key: "uploads/image.jpg",
        content_type: "image/jpeg",
        user_id: author.id
      }

      changeset = Image.changeset(%Image{}, attrs)
      refute changeset.valid?
      assert %{url: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid without content_type", %{author: author} do
      attrs = %{
        filename: "image.jpg",
        storage_key: "uploads/image.jpg",
        url: "https://cdn.example.com/image.jpg",
        user_id: author.id
      }

      changeset = Image.changeset(%Image{}, attrs)
      refute changeset.valid?
      assert %{content_type: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid without user_id" do
      attrs = %{
        filename: "image.jpg",
        storage_key: "uploads/image.jpg",
        url: "https://cdn.example.com/image.jpg",
        content_type: "image/jpeg"
      }

      changeset = Image.changeset(%Image{}, attrs)
      refute changeset.valid?
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates alt_text maximum length", %{author: author} do
      long_alt = String.duplicate("a", 126)

      attrs = %{
        filename: "image.jpg",
        storage_key: "uploads/image.jpg",
        url: "https://cdn.example.com/image.jpg",
        content_type: "image/jpeg",
        user_id: author.id,
        alt_text: long_alt
      }

      changeset = Image.changeset(%Image{}, attrs)
      refute changeset.valid?
      assert %{alt_text: [_]} = errors_on(changeset)
    end

    test "valid with all optional fields", %{author: author} do
      attrs = %{
        filename: "image.jpg",
        storage_key: "uploads/image.jpg",
        url: "https://cdn.example.com/image.jpg",
        content_type: "image/jpeg",
        user_id: author.id,
        file_size: 12345,
        alt_text: "A beautiful sunset"
      }

      changeset = Image.changeset(%Image{}, attrs)
      assert changeset.valid?
    end
  end

  describe "associate_changeset/2" do
    test "can associate with post" do
      image = %Image{}
      changeset = Image.associate_changeset(image, %{post_id: 1, alt_text: "Test"})
      assert Ecto.Changeset.get_change(changeset, :post_id) == 1
      assert Ecto.Changeset.get_change(changeset, :alt_text) == "Test"
    end

    test "validates alt_text maximum length" do
      long_alt = String.duplicate("a", 126)
      image = %Image{}
      changeset = Image.associate_changeset(image, %{alt_text: long_alt})
      refute changeset.valid?
      assert %{alt_text: [_]} = errors_on(changeset)
    end
  end
end
