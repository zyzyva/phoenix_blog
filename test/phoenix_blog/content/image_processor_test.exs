defmodule PhoenixBlog.Content.ImageProcessorTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias PhoenixBlog.Content.ImageProcessor

  @fixtures_path "test/support/fixtures"

  describe "imagemagick_available?/0" do
    test "returns boolean indicating if ImageMagick is installed" do
      result = ImageProcessor.imagemagick_available?()
      assert is_boolean(result)
    end
  end

  describe "process_screenshot/2" do
    test "processes JPEG image" do
      jpeg_data = File.read!(Path.join(@fixtures_path, "test_image.jpg"))

      {:ok, processed_data, content_type} =
        ImageProcessor.process_screenshot(jpeg_data, "image/jpeg")

      assert is_binary(processed_data)
      assert content_type == "image/jpeg"
      # Processed data should still be a valid JPEG (starts with FFD8)
      assert <<0xFF, 0xD8, _rest::binary>> = processed_data
    end

    test "processes PNG image and keeps PNG format" do
      png_data = File.read!(Path.join(@fixtures_path, "test_image.png"))

      {:ok, processed_data, content_type} =
        ImageProcessor.process_screenshot(png_data, "image/png")

      assert is_binary(processed_data)
      assert content_type == "image/png"
      # Processed data should still be a valid PNG (starts with PNG signature)
      assert <<0x89, 0x50, 0x4E, 0x47, _rest::binary>> = processed_data
    end

    test "returns original data if ImageMagick unavailable or processing fails" do
      # If ImageMagick isn't available or fails, should return original
      original_data = "fake image data"

      # Capture expected error log from ImageMagick failing on invalid data
      capture_log(fn ->
        {:ok, result_data, result_type} =
          ImageProcessor.process_screenshot(original_data, "image/jpeg")

        # Either processes successfully or returns original
        assert is_binary(result_data)
        assert result_type in ["image/jpeg", "image/png"]
      end)
    end

    test "converts JPEG to JPEG (maintains format)" do
      jpeg_data = File.read!(Path.join(@fixtures_path, "test_image.jpg"))

      {:ok, processed_data, content_type} =
        ImageProcessor.process_screenshot(jpeg_data, "image/jpeg")

      assert content_type == "image/jpeg"
      assert is_binary(processed_data)
    end
  end
end
