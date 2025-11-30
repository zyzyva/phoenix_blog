defmodule PhoenixBlog.Content.ImageProcessor do
  @moduledoc """
  Processes images for blog and feature screenshots using ImageMagick.

  Resizes and optimizes images for consistent display in blog posts.
  """

  require Logger

  # Max width for blog content images (prose width is typically ~65ch ~= 720px)
  @max_width 1200
  # Quality for JPEG compression
  @jpeg_quality 85

  @doc """
  Processes a screenshot image for blog use.

  - Resizes to max width of #{@max_width}px (maintains aspect ratio)
  - Converts to optimized JPEG or PNG
  - Strips metadata for smaller file size

  Returns {:ok, processed_binary, content_type} or {:error, reason}
  """
  def process_screenshot(image_data, content_type) do
    if imagemagick_available?() do
      do_process(image_data, content_type)
    else
      Logger.warning("ImageMagick not available, skipping image processing")
      {:ok, image_data, content_type}
    end
  end

  @doc """
  Checks if ImageMagick is available.
  """
  def imagemagick_available? do
    case System.cmd("which", ["magick"], stderr_to_stdout: true) do
      {path, 0} when path != "" -> true
      _ -> false
    end
  end

  defp do_process(image_data, content_type) do
    # Create temp files for input and output
    input_ext = extension_for_type(content_type)
    output_ext = output_extension(content_type)
    output_type = output_content_type(content_type)

    input_path = temp_path(input_ext)
    output_path = temp_path(output_ext)

    try do
      # Write input file
      File.write!(input_path, image_data)

      # Build ImageMagick command
      args = build_magick_args(input_path, output_path, output_ext)

      case System.cmd("magick", args, stderr_to_stdout: true) do
        {_, 0} ->
          processed_data = File.read!(output_path)
          {:ok, processed_data, output_type}

        {error_output, _exit_code} ->
          Logger.error("ImageMagick processing failed: #{error_output}")
          # Return original if processing fails
          {:ok, image_data, content_type}
      end
    after
      # Clean up temp files
      File.rm(input_path)
      File.rm(output_path)
    end
  end

  defp build_magick_args(input_path, output_path, output_ext) do
    base_args = [
      input_path,
      # Resize if wider than max, maintain aspect ratio
      "-resize",
      "#{@max_width}x>",
      # Strip metadata (EXIF, etc.)
      "-strip",
      # Auto-orient based on EXIF
      "-auto-orient"
    ]

    quality_args =
      if output_ext in [".jpg", ".jpeg"] do
        ["-quality", "#{@jpeg_quality}"]
      else
        # PNG optimization
        ["-quality", "90"]
      end

    base_args ++ quality_args ++ [output_path]
  end

  defp extension_for_type("image/png"), do: ".png"
  defp extension_for_type("image/jpeg"), do: ".jpg"
  defp extension_for_type("image/jpg"), do: ".jpg"
  defp extension_for_type("image/webp"), do: ".webp"
  defp extension_for_type(_), do: ".png"

  # Keep PNG for screenshots with transparency/text, convert others to JPEG
  defp output_extension("image/png"), do: ".png"
  defp output_extension(_), do: ".jpg"

  defp output_content_type("image/png"), do: "image/png"
  defp output_content_type(_), do: "image/jpeg"

  defp temp_path(extension) do
    uuid = Ecto.UUID.generate() |> String.slice(0, 8)
    Path.join(System.tmp_dir!(), "screenshot_#{uuid}#{extension}")
  end
end
