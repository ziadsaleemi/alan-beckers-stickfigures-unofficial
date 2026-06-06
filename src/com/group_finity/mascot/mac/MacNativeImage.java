package com.group_finity.mascot.mac;

import com.group_finity.mascot.image.NativeImage;

import java.awt.Rectangle;
import java.awt.Shape;
import java.awt.geom.Area;
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
        final Area area = new Area();
        final int width = image.getWidth();
        final int height = image.getHeight();

        for (int y = 0; y < height; y++) {
            int runStart = -1;
            for (int x = 0; x < width; x++) {
                final boolean opaque = ((image.getRGB(x, y) >>> 24) & 0xff) > 0;
                if (opaque && runStart < 0) {
                    runStart = x;
                } else if (!opaque && runStart >= 0) {
                    area.add(new Area(new Rectangle(runStart, y, x - runStart, 1)));
                    runStart = -1;
                }
            }

            if (runStart >= 0) {
                area.add(new Area(new Rectangle(runStart, y, width - runStart, 1)));
            }
        }

        return area;
    }
}
