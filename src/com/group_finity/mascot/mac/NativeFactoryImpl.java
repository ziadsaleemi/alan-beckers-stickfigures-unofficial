package com.group_finity.mascot.mac;

/**
 * macOS factory bridge.
 *
 * The original Shimeji-ee runtime auto-selects this package on macOS, but this
 * distribution only shipped the generic and Windows factories. Provide a
 * macOS environment that maps native window bounds into the legacy activeIE
 * API, plus a modern per-pixel transparent window implementation for sprites.
 */
public class NativeFactoryImpl extends com.group_finity.mascot.generic.NativeFactoryImpl {
    private final com.group_finity.mascot.environment.Environment environment = new MacEnvironment();

    public NativeFactoryImpl() {
        super();
    }

    @Override
    public com.group_finity.mascot.environment.Environment getEnvironment() {
        return environment;
    }

    @Override
    public com.group_finity.mascot.image.NativeImage newNativeImage(final java.awt.image.BufferedImage image) {
        return new MacNativeImage(image);
    }

    @Override
    public com.group_finity.mascot.image.TranslucentWindow newTransparentWindow() {
        return new MacTranslucentWindow();
    }
}
