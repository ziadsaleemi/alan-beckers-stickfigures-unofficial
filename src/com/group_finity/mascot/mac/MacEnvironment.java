package com.group_finity.mascot.mac;

import com.group_finity.mascot.environment.Area;
import com.group_finity.mascot.environment.Environment;

import java.awt.GraphicsConfiguration;
import java.awt.GraphicsDevice;
import java.awt.GraphicsEnvironment;
import java.awt.Insets;
import java.awt.Point;
import java.awt.Rectangle;
import java.awt.Toolkit;
import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;

/**
 * macOS environment bridge for the original Shimeji "activeIE" behaviors.
 *
 * The native launcher publishes a single desktop window rectangle to a small
 * tab-separated file. The legacy behavior XML already knows how to land on,
 * sit on, and walk along activeIE, so this class maps that rectangle into the
 * existing API without requiring macOS Accessibility permissions.
 *
 * The work area spans all connected screens and keeps only the menu-bar top
 * inset. Dock insets are intentionally not used for the floor because macOS
 * reports the whole reserved Dock strip, including empty/invisible space.
 */
public class MacEnvironment extends Environment {
    private static final String WINDOW_BOUNDS_PROPERTY = "shimeji.macWindowBoundsFile";
    private static final long READ_INTERVAL_MILLIS = 100L;
    private static final long STALE_WINDOW_MILLIS = 2000L;
    private static final Rectangle HIDDEN_RECTANGLE = new Rectangle(-1, -1, 0, 0);

    private static final Area workArea = new Area();
    private static final Area activeWindow = new Area();

    private long lastReadMillis;
    private WindowSnapshot lastSnapshot = WindowSnapshot.hidden();
    private String activeWindowTitle = "";

    @Override
    public void tick() {
        super.tick();
        workArea.set(getDesktopWorkArea());

        final WindowSnapshot snapshot = readWindowSnapshot();
        final Rectangle bounds = snapshot.bounds;
        final boolean visible = snapshot.visible
                && bounds != null
                && bounds.width > 0
                && bounds.height > 0
                && bounds.intersects(getScreen().toRectangle());

        activeWindow.setVisible(visible);
        activeWindow.set(visible ? bounds : HIDDEN_RECTANGLE);
        activeWindowTitle = visible ? snapshot.title : "";
    }

    public Area getWorkArea() {
        return workArea;
    }

    @Override
    public Area getActiveIE() {
        return activeWindow;
    }

    @Override
    public String getActiveIETitle() {
        return activeWindowTitle;
    }

    @Override
    public void moveActiveIE(final Point point) {
        // Moving other apps' windows on macOS requires Accessibility permission.
        // The launcher intentionally limits this bridge to passive bounds reads.
    }

    @Override
    public void restoreIE() {
        // No-op on macOS.
    }

    @Override
    public void refreshCache() {
        lastSnapshot = WindowSnapshot.hidden();
        lastReadMillis = 0L;
    }

    @Override
    public void dispose() {
        // No native resources are owned by this environment.
    }

    private Rectangle getDesktopWorkArea() {
        final Rectangle fallbackScreen = getScreen().toRectangle();

        try {
            final GraphicsEnvironment environment = GraphicsEnvironment.getLocalGraphicsEnvironment();
            final Toolkit toolkit = Toolkit.getDefaultToolkit();
            int left = Integer.MAX_VALUE;
            int top = Integer.MIN_VALUE;
            int right = Integer.MIN_VALUE;
            int bottom = Integer.MIN_VALUE;

            for (final GraphicsDevice device : environment.getScreenDevices()) {
                final GraphicsConfiguration configuration = device.getDefaultConfiguration();
                final Rectangle bounds = configuration.getBounds();
                final Insets insets = toolkit.getScreenInsets(configuration);

                left = Math.min(left, bounds.x);
                top = Math.max(top, bounds.y + Math.max(0, insets.top));
                right = Math.max(right, bounds.x + bounds.width);
                bottom = Math.max(bottom, bounds.y + bounds.height);
            }

            if (left < right && top < bottom) {
                return new Rectangle(left, top, right - left, bottom - top);
            }
        } catch (final RuntimeException ignored) {
            // Fall back to the full screen if AWT cannot report insets.
        }

        return fallbackScreen;
    }

    private WindowSnapshot readWindowSnapshot() {
        final long now = System.currentTimeMillis();
        if (now - lastReadMillis < READ_INTERVAL_MILLIS) {
            return lastSnapshot;
        }

        lastReadMillis = now;
        final String path = System.getProperty(WINDOW_BOUNDS_PROPERTY, "").trim();
        if (path.isEmpty()) {
            lastSnapshot = WindowSnapshot.hidden();
            return lastSnapshot;
        }

        final File file = new File(path);
        if (!file.isFile() || now - file.lastModified() > STALE_WINDOW_MILLIS) {
            lastSnapshot = WindowSnapshot.hidden();
            return lastSnapshot;
        }

        try {
            final String content = new String(Files.readAllBytes(file.toPath()), StandardCharsets.UTF_8);
            lastSnapshot = parseWindowSnapshot(content);
        } catch (final IOException | RuntimeException ignored) {
            lastSnapshot = WindowSnapshot.hidden();
        }

        return lastSnapshot;
    }

    private WindowSnapshot parseWindowSnapshot(final String content) {
        if (content == null || content.trim().isEmpty()) {
            return WindowSnapshot.hidden();
        }

        final String firstLine = content.split("\\R", 2)[0];
        final String[] parts = firstLine.split("\t", 6);
        if (parts.length < 5 || !"1".equals(parts[0])) {
            return WindowSnapshot.hidden();
        }

        final int left = Integer.parseInt(parts[1]);
        final int top = Integer.parseInt(parts[2]);
        final int width = Integer.parseInt(parts[3]);
        final int height = Integer.parseInt(parts[4]);
        if (width <= 0 || height <= 0) {
            return WindowSnapshot.hidden();
        }

        final String title = parts.length >= 6 ? parts[5] : "";
        return new WindowSnapshot(true, new Rectangle(left, top, width, height), title);
    }

    private static final class WindowSnapshot {
        private final boolean visible;
        private final Rectangle bounds;
        private final String title;

        private WindowSnapshot(final boolean visible, final Rectangle bounds, final String title) {
            this.visible = visible;
            this.bounds = bounds;
            this.title = title == null ? "" : title;
        }

        private static WindowSnapshot hidden() {
            return new WindowSnapshot(false, HIDDEN_RECTANGLE, "");
        }
    }
}
