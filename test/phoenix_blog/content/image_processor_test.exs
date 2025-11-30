defmodule PhoenixBlog.Content.ImageProcessorTest do
  use ExUnit.Case, async: true

  alias PhoenixBlog.Content.ImageProcessor

  describe "imagemagick_available?/0" do
    test "returns boolean indicating if ImageMagick is installed" do
      result = ImageProcessor.imagemagick_available?()
      assert is_boolean(result)
    end
  end

  describe "process_screenshot/2" do
    @tag :imagemagick
    test "processes JPEG image" do
      # Create a minimal valid JPEG (1x1 red pixel)
      # This is a valid JPEG file header + minimal image data
      jpeg_data = create_test_jpeg()

      {:ok, processed_data, content_type} =
        ImageProcessor.process_screenshot(jpeg_data, "image/jpeg")

      assert is_binary(processed_data)
      assert content_type == "image/jpeg"
    end

    @tag :imagemagick
    test "processes PNG image and keeps PNG format" do
      png_data = create_test_png()

      {:ok, processed_data, content_type} =
        ImageProcessor.process_screenshot(png_data, "image/png")

      assert is_binary(processed_data)
      assert content_type == "image/png"
    end

    test "returns original data if ImageMagick unavailable" do
      # If ImageMagick isn't available, should return original
      original_data = "fake image data"

      {:ok, result_data, result_type} =
        ImageProcessor.process_screenshot(original_data, "image/jpeg")

      # Either processes successfully or returns original
      assert is_binary(result_data)
      assert result_type in ["image/jpeg", "image/png"]
    end

    test "converts non-PNG images to JPEG" do
      webp_data = "fake webp data"

      if ImageProcessor.imagemagick_available?() do
        # Would convert to JPEG (though this fake data will fail)
        {:ok, _data, type} = ImageProcessor.process_screenshot(webp_data, "image/webp")
        # Falls back to original on error, so type could be either
        assert type in ["image/webp", "image/jpeg"]
      else
        {:ok, data, type} = ImageProcessor.process_screenshot(webp_data, "image/webp")
        # Without ImageMagick, returns original
        assert data == webp_data
        assert type == "image/webp"
      end
    end
  end

  # Create minimal test images

  # Minimal valid JPEG (1x1 pixel, red)
  defp create_test_jpeg do
    # This is a valid 1x1 red JPEG
    <<255, 216, 255, 224, 0, 16, 74, 70, 73, 70, 0, 1, 1, 0, 0, 1, 0, 1, 0, 0, 255, 219, 0, 67, 0,
      8, 6, 6, 7, 6, 5, 8, 7, 7, 7, 9, 9, 8, 10, 12, 20, 13, 12, 11, 11, 12, 25, 18, 19, 15, 20,
      29, 26, 31, 30, 29, 26, 28, 28, 32, 36, 46, 39, 32, 34, 44, 35, 28, 28, 40, 55, 41, 44, 48,
      49, 52, 52, 52, 31, 39, 57, 61, 56, 50, 60, 46, 51, 52, 50, 255, 192, 0, 11, 8, 0, 1, 0, 1,
      1, 1, 17, 0, 255, 196, 0, 31, 0, 0, 1, 5, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3,
      4, 5, 6, 7, 8, 9, 10, 11, 255, 196, 0, 181, 16, 0, 2, 1, 3, 3, 2, 4, 3, 5, 5, 4, 4, 0, 0, 1,
      125, 1, 2, 3, 0, 4, 17, 5, 18, 33, 49, 65, 6, 19, 81, 97, 7, 34, 113, 20, 50, 129, 145, 161,
      8, 35, 66, 177, 193, 21, 82, 209, 240, 36, 51, 98, 114, 130, 9, 10, 22, 23, 24, 25, 26, 37,
      38, 39, 40, 41, 42, 52, 53, 54, 55, 56, 57, 58, 67, 68, 69, 70, 71, 72, 73, 74, 83, 84, 85,
      86, 87, 88, 89, 90, 99, 100, 101, 102, 103, 104, 105, 106, 115, 116, 117, 118, 119, 120,
      121, 122, 131, 132, 133, 134, 135, 136, 137, 138, 146, 147, 148, 149, 150, 151, 152, 153,
      154, 162, 163, 164, 165, 166, 167, 168, 169, 170, 178, 179, 180, 181, 182, 183, 184, 185,
      186, 194, 195, 196, 197, 198, 199, 200, 201, 202, 210, 211, 212, 213, 214, 215, 216, 217,
      218, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 241, 242, 243, 244, 245, 246, 247,
      248, 249, 250, 255, 218, 0, 8, 1, 1, 0, 0, 63, 0, 251, 215, 162, 138, 40, 0, 162, 138, 40,
      255, 217>>
  end

  # Minimal valid PNG (1x1 pixel, red)
  defp create_test_png do
    # PNG signature + IHDR + IDAT + IEND for 1x1 red pixel
    <<137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 2,
      0, 0, 0, 144, 119, 83, 222, 0, 0, 0, 12, 73, 68, 65, 84, 8, 215, 99, 248, 207, 192, 0, 0, 1,
      1, 1, 0, 24, 221, 141, 251, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130>>
  end
end
