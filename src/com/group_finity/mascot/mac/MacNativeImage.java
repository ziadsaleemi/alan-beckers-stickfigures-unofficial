package com.group_finity.mascot.mac;

import com.group_finity.mascot.image.NativeImage;

import java.awt.Rectangle;
import java.awt.Shape;
import java.awt.image.BufferedImage;

final class MacNativeImage implements NativeImage {
    private final BufferedImage managedImage;
    private final Shape alphaMask;

    MacNativeImage(final BufferedImage managedImage) {
        this.managedImage = managedImage;
        this.alphaMask = createAlphaMask(managedImage);
    }

    BufferedImage getManagedImage() {
        return managedImage;
    }

    Shape getAlphaMask() {
        return alphaMask;
    }

    private static Shape createAlphaMask(final BufferedImage image) {
        final int width = image.getWidth();
        final int height = image.getHeight();
        int minX = width;
        int minY = height;
        int maxX = -1;
        int maxY = -1;

        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                final boolean opaque = ((image.getRGB(x, y) >>> 24) & 0xff) > 0;
                if (opaque) {
                    minX = Math.min(minX, x);
                    minY = Math.min(minY, y);
                    maxX = Math.max(maxX, x);
                    maxY = Math.max(maxY, y);
                }
            }
        }

        if (maxX < minX || maxY < minY) {
            return new Rectangle(0, 0, 0, 0);
        }

        return new Rectangle(minX, minY, maxX - minX + 1, maxY - minY + 1);
    }
}
