package com.group_finity.mascot.generic;

import com.group_finity.mascot.image.NativeImage;
import com.group_finity.mascot.image.TranslucentWindow;
import com.sun.jna.examples.WindowUtils;

import javax.swing.JComponent;
import javax.swing.JPanel;
import javax.swing.JWindow;
import java.awt.AlphaComposite;
import java.awt.Color;
import java.awt.Component;
import java.awt.Container;
import java.awt.Graphics;
import java.awt.Graphics2D;
import java.awt.Rectangle;
import java.awt.Toolkit;
import java.lang.reflect.InvocationTargetException;
import javax.swing.SwingUtilities;

class GenericTranslucentWindow extends JWindow implements TranslucentWindow {
    private static final long serialVersionUID = 1L;

    private GenericNativeImage image;
    private JPanel panel;
    private float alpha = 1.0f;

    GenericTranslucentWindow() {
        super(WindowUtils.getAlphaCompatibleGraphicsConfiguration());
        init();
        panel = new JPanel() {
            private static final long serialVersionUID = 1L;

            @Override
            protected void paintComponent(final Graphics graphics) {
                final Graphics2D graphics2D = (Graphics2D) graphics.create();
                try {
                    graphics2D.setComposite(AlphaComposite.Clear);
                    graphics2D.fillRect(0, 0, getWidth(), getHeight());
                    graphics2D.setComposite(AlphaComposite.Src);

                    final GenericNativeImage currentImage = getImage();
                    if (currentImage != null) {
                        graphics2D.drawImage(currentImage.getManagedImage(), 0, 0, null);
                    }
                } finally {
                    graphics2D.dispose();
                }
            }
        };
        panel.setOpaque(false);
        panel.setDoubleBuffered(false);
        setContentPane(panel);
        getRootPane().setOpaque(false);
        getLayeredPane().setOpaque(false);
    }

    private void init() {
        System.setProperty("sun.java2d.noddraw", "true");
        System.setProperty("sun.java2d.opengl", "true");
        getRootPane().putClientProperty("apple.awt.draggableWindowBackground", Boolean.FALSE);
        setBackground(new Color(0, 0, 0, 0));
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
            graphics2D.setComposite(AlphaComposite.SrcOver);
            super.paint(graphics2D);
        } finally {
            graphics2D.dispose();
        }
    }

    @Override
    public void setBounds(final int x, final int y, final int width, final int height) {
        final Rectangle oldBounds = getBounds();
        final boolean sizeChanged = oldBounds.width != width || oldBounds.height != height;

        if (sizeChanged && isDisplayable()) {
            clearNativeMask();
        }

        super.setBounds(x, y, width, height);
    }

    @Override
    public void setVisible(final boolean visible) {
        if (visible) {
            WindowUtils.setWindowTransparent(this, true);
        }
        super.setVisible(visible);
    }

    @Override
    protected void addImpl(final Component component, final Object constraints, final int index) {
        super.addImpl(component, constraints, index);
        if (component instanceof JComponent) {
            ((JComponent) component).setOpaque(false);
        }
    }

    public void setAlpha(final float alpha) {
        this.alpha = alpha;
        WindowUtils.setWindowAlpha(this, alpha);
    }

    public float getAlpha() {
        return alpha;
    }

    @Override
    public Component asComponent() {
        return this;
    }

    @Override
    public String toString() {
        return "LayeredWindow[hashCode=" + hashCode() + ",bounds=" + getBounds() + "]";
    }

    public GenericNativeImage getImage() {
        return image;
    }

    @Override
    public void setImage(final NativeImage image) {
        this.image = (GenericNativeImage) image;
    }

    @Override
    public void updateImage() {
        final GenericNativeImage currentImage = getImage();
        if (currentImage == null) {
            return;
        }

        repaintImageNow(currentImage);
    }

    private void repaintImageNow(final GenericNativeImage currentImage) {
        final Runnable repaintTask = () -> {
            clearNativeMask();
            WindowUtils.setWindowMask(this, currentImage.getIcon());
            validate();

            final Container contentPane = getContentPane();
            contentPane.validate();
            contentPane.repaint(0, 0, contentPane.getWidth(), contentPane.getHeight());

            if (panel != null && panel.isShowing()) {
                panel.paintImmediately(0, 0, panel.getWidth(), panel.getHeight());
            }

            repaint(0, 0, getWidth(), getHeight());
            Toolkit.getDefaultToolkit().sync();
        };

        if (SwingUtilities.isEventDispatchThread()) {
            repaintTask.run();
            return;
        }

        try {
            SwingUtilities.invokeAndWait(repaintTask);
        } catch (final InterruptedException exception) {
            Thread.currentThread().interrupt();
            SwingUtilities.invokeLater(repaintTask);
        } catch (final InvocationTargetException exception) {
            SwingUtilities.invokeLater(repaintTask);
        }
    }

    private void clearNativeMask() {
        WindowUtils.setWindowMask(this, new java.awt.geom.Area());
    }
}
