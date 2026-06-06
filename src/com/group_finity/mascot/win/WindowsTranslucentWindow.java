package com.group_finity.mascot.win;

import com.group_finity.mascot.image.NativeImage;
import com.group_finity.mascot.image.TranslucentWindow;
import com.group_finity.mascot.win.jna.BLENDFUNCTION;
import com.group_finity.mascot.win.jna.Gdi32;
import com.group_finity.mascot.win.jna.POINT;
import com.group_finity.mascot.win.jna.RECT;
import com.group_finity.mascot.win.jna.SIZE;
import com.group_finity.mascot.win.jna.User32;
import com.sun.jna.Native;
import com.sun.jna.Pointer;

import javax.swing.JWindow;
import javax.swing.SwingUtilities;
import java.awt.Component;
import java.awt.Graphics;
import java.lang.reflect.InvocationTargetException;

class WindowsTranslucentWindow extends JWindow implements TranslucentWindow {
    private static final long serialVersionUID = 1L;

    private WindowsNativeImage image;
    private int alpha = 255;

    @Override
    public Component asComponent() {
        return this;
    }

    @Override
    public void paint(final Graphics graphics) {
        final WindowsNativeImage currentImage = getImage();
        if (currentImage != null) {
            paint(currentImage.getHandle(), getAlpha());
        }
    }

    private void paint(final Pointer bitmapHandle, final int alpha) {
        final Pointer windowHandle = Native.getComponentPointer(this);
        if (User32.INSTANCE.IsWindow(windowHandle) == 0) {
            return;
        }

        final int extendedStyle = User32.INSTANCE.GetWindowLongW(windowHandle, User32.GWL_EXSTYLE);
        if ((extendedStyle & User32.WS_EX_LAYERED) == 0) {
            User32.INSTANCE.SetWindowLongW(windowHandle, User32.GWL_EXSTYLE, extendedStyle | User32.WS_EX_LAYERED);
        }

        Pointer screenDc = null;
        Pointer memoryDc = null;
        Pointer previousBitmap = null;

        try {
            screenDc = User32.INSTANCE.GetDC(windowHandle);
            memoryDc = Gdi32.INSTANCE.CreateCompatibleDC(screenDc);
            previousBitmap = Gdi32.INSTANCE.SelectObject(memoryDc, bitmapHandle);

            final RECT windowRect = new RECT();
            User32.INSTANCE.GetWindowRect(windowHandle, windowRect);

            final BLENDFUNCTION blend = new BLENDFUNCTION();
            blend.BlendOp = BLENDFUNCTION.AC_SRC_OVER;
            blend.BlendFlags = 0;
            blend.SourceConstantAlpha = (byte) alpha;
            blend.AlphaFormat = BLENDFUNCTION.AC_SRC_ALPHA;

            final POINT destination = new POINT();
            destination.x = windowRect.left;
            destination.y = windowRect.top;

            final SIZE size = new SIZE();
            size.cx = windowRect.Width();
            size.cy = windowRect.Height();

            final POINT source = new POINT();
            source.x = 0;
            source.y = 0;

            User32.INSTANCE.UpdateLayeredWindow(
                    windowHandle,
                    Pointer.NULL,
                    destination,
                    size,
                    memoryDc,
                    source,
                    0,
                    blend,
                    User32.ULW_ALPHA
            );
        } finally {
            if (screenDc != null) {
                User32.INSTANCE.ReleaseDC(windowHandle, screenDc);
            }
            if (memoryDc != null) {
                if (previousBitmap != null) {
                    Gdi32.INSTANCE.SelectObject(memoryDc, previousBitmap);
                }
                Gdi32.INSTANCE.DeleteDC(memoryDc);
            }
        }
    }

    private WindowsNativeImage getImage() {
        return image;
    }

    @Override
    public void setImage(final NativeImage image) {
        this.image = (WindowsNativeImage) image;
    }

    public int getAlpha() {
        return alpha;
    }

    public void setAlpha(final int alpha) {
        this.alpha = alpha;
    }

    @Override
    public void updateImage() {
        if (getImage() == null) {
            return;
        }

        final Runnable paintTask = () -> {
            paint(null);
            repaint();
        };

        if (SwingUtilities.isEventDispatchThread()) {
            paintTask.run();
            return;
        }

        try {
            SwingUtilities.invokeAndWait(paintTask);
        } catch (final InterruptedException exception) {
            Thread.currentThread().interrupt();
            SwingUtilities.invokeLater(paintTask);
        } catch (final InvocationTargetException exception) {
            SwingUtilities.invokeLater(paintTask);
        }
    }
}
