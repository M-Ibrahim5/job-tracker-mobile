package com.jobtrail.user.me;

import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.Iterator;
import java.util.Optional;
import javax.imageio.ImageIO;
import javax.imageio.ImageReader;
import javax.imageio.stream.ImageInputStream;

/**
 * Decodes an uploaded avatar and encodes a fresh copy. Only the pixels survive, so metadata (EXIF,
 * including GPS location) and anything appended to the file are dropped, and what is served is
 * always a plain image. Large images are scaled down to {@link #MAX_SIDE}.
 */
final class AvatarImages {

  /** Longest side of a stored avatar, in pixels. */
  static final int MAX_SIDE = 512;
  /** Refuse to decode larger images (a small file can declare huge dimensions). */
  static final long MAX_SOURCE_PIXELS = 16_000_000L;

  private AvatarImages() {}

  /** The re-encoded image in [format] ("png" or "jpg"), or empty when it is not a readable image. */
  static Optional<byte[]> normalise(byte[] bytes, String format) {
    try {
      BufferedImage source = decode(bytes);
      if (source == null) {
        return Optional.empty();
      }
      BufferedImage scaled = scale(source, format.equals("jpg"));
      ByteArrayOutputStream out = new ByteArrayOutputStream();
      if (!ImageIO.write(scaled, format.equals("jpg") ? "jpeg" : "png", out)) {
        return Optional.empty();
      }
      return Optional.of(out.toByteArray());
    } catch (IOException | RuntimeException e) {
      return Optional.empty();
    }
  }

  private static BufferedImage decode(byte[] bytes) throws IOException {
    try (ImageInputStream in = ImageIO.createImageInputStream(new ByteArrayInputStream(bytes))) {
      if (in == null) {
        return null;
      }
      Iterator<ImageReader> readers = ImageIO.getImageReaders(in);
      if (!readers.hasNext()) {
        return null;
      }
      ImageReader reader = readers.next();
      try {
        reader.setInput(in, true, true);
        // Reads only the header: checked before any pixel memory is allocated.
        long pixels = (long) reader.getWidth(0) * reader.getHeight(0);
        if (pixels <= 0 || pixels > MAX_SOURCE_PIXELS) {
          return null;
        }
        return reader.read(0);
      } finally {
        reader.dispose();
      }
    }
  }

  private static BufferedImage scale(BufferedImage source, boolean opaque) {
    int w = source.getWidth();
    int h = source.getHeight();
    double factor = Math.min(1.0, (double) MAX_SIDE / Math.max(w, h));
    int tw = Math.max(1, (int) Math.round(w * factor));
    int th = Math.max(1, (int) Math.round(h * factor));
    BufferedImage target = new BufferedImage(tw, th, opaque ? BufferedImage.TYPE_INT_RGB : BufferedImage.TYPE_INT_ARGB);
    Graphics2D g = target.createGraphics();
    try {
      g.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BILINEAR);
      g.setRenderingHint(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_QUALITY);
      if (opaque) {
        // JPEG has no alpha: flatten onto white.
        g.setColor(java.awt.Color.WHITE);
        g.fillRect(0, 0, tw, th);
      }
      g.drawImage(source, 0, 0, tw, th, null);
    } finally {
      g.dispose();
    }
    return target;
  }
}
