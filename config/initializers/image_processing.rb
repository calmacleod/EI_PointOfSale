# frozen_string_literal: true

# Extends the image_processing Vips processor with a trim_whitespace
# operation that removes blank borders from images. Used by Active Storage
# variants to crop whitespace off store logos for receipt printing.
#
# Usage in a variant:
#   logo.variant(trim_whitespace: true, resize_to_limit: [384, 384])
#
require "image_processing/vips"

ImageProcessing::Vips::Processor.class_eval do
  # Detects and crops away uniform-colour borders around the image.
  # Uses the pixel at (0,0) as the background reference so it works
  # with both white and transparent backgrounds.
  def trim_whitespace(_value = true)
    left, top, width, height = image.find_trim(threshold: 15.0)

    if width.positive? && height.positive?
      image.crop(left, top, width, height)
    else
      image
    end
  end
end
