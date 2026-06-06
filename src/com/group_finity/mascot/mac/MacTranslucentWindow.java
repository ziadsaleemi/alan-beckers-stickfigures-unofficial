package com.group_finity.mascot.mac;

import com.group_finity.mascot.image.NativeImage;
import com.group_finity.mascot.image.TranslucentWindow;

import javax.swing.JWindow;
import javax.swing.SwingUtilities;
import java.awt.AlphaComposite;
import java.awt.Color;
import java.awt.Component;
import java.awt.Graphics;
import java.awt.Graphics2D;
import java.awt.Rectangle;
import java.awt.Shape;
import java.awt.Toolkit;
import java.awt.Window;
import java.lang.reflect.InvocationTargetException;

final class MacTranslucentWindow extends JWindow implements TranslucentWindow {
    private static final long serialVersionUID = 1L;

    private volatile MacNativeImage image;
    private boolean dispatchReady;

    MacTranslucentWindow() {
        super();
        setType(Window.Type.POPUP);
        setFocusableWindowState(false);
        setAutoRequestFocus(false);
        getRootPane().putClientProperty("apple.awt.draggableWindowBackground", Boolean.FALSE);
        getRootPane().setOpaque(false);
        getLayeredPane().setOpaque(false);
        getContentPane().setBackground(new Color(0, 0, 0, 0));
        setBackground(new Color(0, 0, 0, 0));
        dispatchReady = true;
    }

    @Override
    public void update(final Graphics graphics) {
        paint(graphics);
    }

    @Override
    public void paint(final Graphics graphics) {
        if (graphics == null) {
            return;
        }

        final Graphics2D graphics2D = (Graphics2D) graphics.create();
        try {
            graphics2D.setComposite(AlphaComposite.Clear);
            graphics2D.fillRect(0, 0, getWidth(), getHeight());

            final MacNativeImage currentImage = getImage();
            if (currentImage != null) {
                graphics2D.setComposite(AlphaComposite.Src);
                graphics2D.drawImage(currentImage.getManagedImage(), 0, 0, null);
            }
        } finally {
            graphics2D.dispose();
        }
    }

    @Override
    public void setVisible(final boolean visible) {
        runOnEventThread(() -> {
            MacTranslucentWindow.super.setVisible(visible);
            if (visible) {
                setAlwaysOnTop(true);
                toFront();
                paintCurrentImage();
            }
        });
    }

    @Override
    public void setBounds(final int x, final int y, final int width, final int height) {
        runOnEventThread(() -> MacTranslucentWindow.super.setBounds(x, y, width, height));
    }

    @Override
    public void setBounds(final Rectangle rectangle) {
        setBounds(rectangle.x, rectangle.y, rectangle.width, rectangle.height);
    }

    @Override
    public Component asComponent() {
        return this;
    }

    private MacNativeImage getImage() {
        return image;
    }

    @Override
    public void setImage(final NativeImage image) {
        this.image = (MacNativeImage) image;
    }

    @Override
    public void updateImage() {
        final MacNativeImage currentImage = getImage();
        if (currentImage == null) {
            return;
        }

        runOnEventThread(this::paintCurrentImage);
    }

    private void paintCurrentImage() {
        final MacNativeImage currentImage = getImage();
        if (currentImage == null || getWidth() <= 0 || getHeight() <= 0) {
            return;
        }

        final Shape currentMask = currentImage.getAlphaMask();

        if (isDisplayable()) {
            // Clear the previous frame before narrowing the native window shape.
            setShape(null);
            final Graphics clearGraphics = getGraphics();
            if (clearGraphics != null) {
                try {
                    clear(clearGraphics);
                } finally {
                    clearGraphics.dispose();
                }
            }
        }

        setShape(currentMask);
        if (isShowing()) {
            toFront();
        }

        final Graphics graphics = getGraphics();
        if (graphics != null) {
            try {
                paint(graphics);
            } finally {
                graphics.dispose();
            }
        }

        Toolkit.getDefaultToolkit().sync();
    }

    private void clear(final Graphics graphics) {
        final Graphics2D graphics2D = (Graphics2D) graphics.create();
        try {
            graphics2D.setComposite(AlphaComposite.Clear);
            graphics2D.fillRect(0, 0, getWidth(), getHeight());
        } finally {
            graphics2D.dispose();
        }
    }

    private void runOnEventThread(final Runnable task) {
        if (!dispatchReady || SwingUtilities.isEventDispatchThread() || Thread.holdsLock(getTreeLock())) {
            task.run();
            return;
        }

        try {
            SwingUtilities.invokeAndWait(task);
        } catch (final InterruptedException exception) {
            Thread.currentThread().interrupt();
            SwingUtilities.invokeLater(task);
        } catch (final InvocationTargetException exception) {
            SwingUtilities.invokeLater(task);
        }
    }
}
