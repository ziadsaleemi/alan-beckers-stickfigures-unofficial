package com.group_finity.mascot;

import javax.swing.Box;
import javax.swing.BoxLayout;
import javax.swing.JButton;
import javax.swing.JDialog;
import javax.swing.JLabel;
import javax.swing.JPanel;
import javax.swing.JSeparator;
import javax.swing.SwingConstants;
import javax.swing.border.CompoundBorder;
import javax.swing.border.EmptyBorder;
import javax.swing.border.LineBorder;
import java.awt.Color;
import java.awt.Component;
import java.awt.Desktop;
import java.awt.Dimension;
import java.awt.Frame;
import java.awt.Font;
import java.awt.GraphicsEnvironment;
import java.awt.Rectangle;
import java.awt.TrayIcon;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.awt.event.MouseEvent;
import java.awt.event.MouseListener;
import java.io.File;
import java.io.IOException;
import java.lang.reflect.Constructor;
import java.lang.reflect.Field;
import java.util.Arrays;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.MissingResourceException;

class Main$1 implements MouseListener {
    private static final Color BACKGROUND = new Color(245, 247, 250);
    private static final Color PANEL_BACKGROUND = Color.WHITE;
    private static final Color BORDER = new Color(218, 224, 232);
    private static final Color MUTED_TEXT = new Color(88, 96, 109);

    final TrayIcon val$icon;
    final Main this$0;

    Main$1(final Main main, final TrayIcon icon) {
        this.this$0 = main;
        this.val$icon = icon;
    }

    @Override
    public void mouseClicked(final MouseEvent event) {
    }

    @Override
    public void mousePressed(final MouseEvent event) {
    }

    @Override
    public void mouseReleased(final MouseEvent event) {
        if (event.isPopupTrigger()) {
            showMenu(event);
            return;
        }

        if (event.getButton() == MouseEvent.BUTTON1) {
            this$0.createMascot();
            return;
        }

        if (event.getButton() == MouseEvent.BUTTON2 && event.getClickCount() == 2) {
            toggleAllStickfigures();
        }
    }

    @Override
    public void mouseEntered(final MouseEvent event) {
    }

    @Override
    public void mouseExited(final MouseEvent event) {
    }

    private void showMenu(final MouseEvent event) {
        if (currentDialog() != null) {
            currentDialog().dispose();
        }

        final JDialog dialog = new JDialog(mainFrame(), false);
        setCurrentDialog(dialog);
        final JPanel panel = new JPanel();
        panel.setBackground(BACKGROUND);
        panel.setBorder(new EmptyBorder(scale(12), scale(12), scale(12), scale(12)));
        panel.setLayout(new BoxLayout(panel, BoxLayout.Y_AXIS));

        panel.add(header());
        panel.add(Box.createVerticalStrut(scale(10)));
        panel.add(menuButton(text("CallShimeji"), action("Main$1$1")));
        panel.add(Box.createVerticalStrut(scale(6)));
        panel.add(menuButton(text("FollowCursor"), action("Main$1$2")));
        panel.add(Box.createVerticalStrut(scale(6)));
        panel.add(menuButton(text("ChooseShimeji"), action("Main$1$7")));
        panel.add(Box.createVerticalStrut(scale(6)));
        panel.add(menuButton(text("Settings"), action("Main$1$8")));

        panel.add(sectionSeparator("Desktop"));
        panel.add(menuButton(pausedText(), action("Main$1$11")));
        panel.add(Box.createVerticalStrut(scale(6)));
        panel.add(menuButton(text("ReduceToOne"), action("Main$1$3")));
        panel.add(Box.createVerticalStrut(scale(6)));
        panel.add(menuButton(text("RestoreWindows"), action("Main$1$4")));

        final JButton allowedBehaviours = menuButton(text("AllowedBehaviours"));
        allowedBehaviours.addMouseListener(mouseListener("Main$1$5", allowedBehaviours));
        allowedBehaviours.addActionListener(action("Main$1$6", allowedBehaviours, panel));
        panel.add(Box.createVerticalStrut(scale(6)));
        panel.add(allowedBehaviours);

        panel.add(sectionSeparator("Tools"));
        panel.add(menuButton("Open Logs", event1 -> openLogs()));

        final JButton language = menuButton(text("Language"));
        language.addMouseListener(mouseListener("Main$1$9", language));
        language.addActionListener(action("Main$1$10", panel, language));
        panel.add(Box.createVerticalStrut(scale(6)));
        panel.add(language);

        panel.add(Box.createVerticalStrut(scale(6)));
        panel.add(menuButton(text("DismissAll"), action("Main$1$12")));

        dialog.add(panel);
        dialog.setIconImage(val$icon.getImage());
        dialog.setTitle(text("ShimejiEE"));
        dialog.setDefaultCloseOperation(JDialog.DISPOSE_ON_CLOSE);
        dialog.setAlwaysOnTop(true);
        dialog.pack();
        dialog.setMinimumSize(dialog.getSize());
        positionDialog(dialog, event);
        dialog.setVisible(true);
    }

    private JPanel header() {
        final JPanel header = new JPanel();
        header.setLayout(new BoxLayout(header, BoxLayout.Y_AXIS));
        header.setBackground(PANEL_BACKGROUND);
        header.setBorder(new CompoundBorder(
                new LineBorder(BORDER, 1, true),
                new EmptyBorder(scale(10), scale(12), scale(10), scale(12))
        ));
        header.setAlignmentX(Component.LEFT_ALIGNMENT);
        header.setMaximumSize(new Dimension(Integer.MAX_VALUE, scale(68)));

        final JLabel title = new JLabel("Alan Beckers Stickfigures");
        title.setFont(title.getFont().deriveFont(Font.BOLD, scaleFont(14)));
        title.setForeground(Color.BLACK);
        title.setAlignmentX(Component.LEFT_ALIGNMENT);

        final JLabel subtitle = new JLabel("Your Own Stickman Companions!");
        subtitle.setFont(subtitle.getFont().deriveFont(Font.PLAIN, scaleFont(12)));
        subtitle.setForeground(MUTED_TEXT);
        subtitle.setAlignmentX(Component.LEFT_ALIGNMENT);

        header.add(title);
        header.add(Box.createVerticalStrut(scale(3)));
        header.add(subtitle);
        return header;
    }

    private Component sectionSeparator(final String title) {
        final JPanel section = new JPanel();
        section.setLayout(new BoxLayout(section, BoxLayout.Y_AXIS));
        section.setBackground(BACKGROUND);
        section.setAlignmentX(Component.LEFT_ALIGNMENT);
        section.setMaximumSize(new Dimension(Integer.MAX_VALUE, scale(34)));

        final JSeparator separator = new JSeparator(SwingConstants.HORIZONTAL);
        separator.setForeground(BORDER);
        separator.setAlignmentX(Component.LEFT_ALIGNMENT);

        final JLabel label = new JLabel(title);
        label.setFont(label.getFont().deriveFont(Font.BOLD, scaleFont(11)));
        label.setForeground(MUTED_TEXT);
        label.setAlignmentX(Component.LEFT_ALIGNMENT);

        section.add(Box.createVerticalStrut(scale(10)));
        section.add(separator);
        section.add(Box.createVerticalStrut(scale(7)));
        section.add(label);
        return section;
    }

    private JButton menuButton(final String title) {
        return menuButton(title, null);
    }

    private JButton menuButton(final String title, final ActionListener actionListener) {
        final JButton button = new JButton(title);
        button.setHorizontalAlignment(SwingConstants.LEFT);
        button.setFocusPainted(false);
        button.setBackground(PANEL_BACKGROUND);
        button.setOpaque(true);
        button.setBorder(new CompoundBorder(
                new LineBorder(BORDER, 1, true),
                new EmptyBorder(scale(7), scale(10), scale(7), scale(10))
        ));
        button.setAlignmentX(Component.LEFT_ALIGNMENT);
        button.setMaximumSize(new Dimension(Integer.MAX_VALUE, scale(34)));
        if (actionListener != null) {
            button.addActionListener(actionListener);
        }
        return button;
    }

    private String pausedText() {
        return text(manager().isPaused() ? "ResumeAnimations" : "PauseAnimations");
    }

    private String text(final String key) {
        try {
            return this$0.getLanguageBundle().getString(key);
        } catch (final MissingResourceException exception) {
            return key;
        }
    }

    private int scale(final int value) {
        try {
            final float dpi = Float.parseFloat(this$0.getProperties().getProperty("MenuDPI", "96"));
            return Math.max(1, Math.round(value * (dpi / 96.0f)));
        } catch (final RuntimeException exception) {
            return value;
        }
    }

    private float scaleFont(final int value) {
        return (float) scale(value);
    }

    private void positionDialog(final JDialog dialog, final MouseEvent event) {
        dialog.setLocation(event.getPoint().x - dialog.getWidth(), event.getPoint().y - dialog.getHeight());

        final Rectangle bounds = GraphicsEnvironment.getLocalGraphicsEnvironment().getMaximumWindowBounds();
        if (dialog.getX() < bounds.getX()) {
            dialog.setLocation(event.getPoint().x, dialog.getY());
        }
        if (dialog.getY() < bounds.getY()) {
            dialog.setLocation(dialog.getX(), event.getPoint().y);
        }
    }

    private void toggleAllStickfigures() {
        if (manager().isExitOnLastRemoved()) {
            manager().setExitOnLastRemoved(false);
            manager().disposeAll();
            return;
        }

        for (final String imageSet : imageSets()) {
            this$0.createMascot(imageSet);
        }
        manager().setExitOnLastRemoved(true);
    }

    private void openLogs() {
        final File logFile = mostRecentLogFile();
        try {
            if (!logFile.exists()) {
                logFile.createNewFile();
            }
            if (Desktop.isDesktopSupported()) {
                Desktop.getDesktop().open(logFile);
            } else {
                Main.showError("Logs are at:\n" + logFile.getAbsolutePath());
            }
        } catch (final IOException exception) {
            Main.showError("Could not open logs:\n" + logFile.getAbsolutePath());
        }
    }

    private File mostRecentLogFile() {
        final File workingDirectory = new File(".");
        final File[] logs = workingDirectory.listFiles((directory, name) ->
                name.startsWith("ShimejieeLog") && name.endsWith(".log")
        );
        if (logs != null && logs.length > 0) {
            Arrays.sort(logs, Comparator.comparingLong(File::lastModified).reversed());
            return logs[0];
        }
        return new File(workingDirectory, "ShimejieeLog0.log");
    }

    private ActionListener action(final String className, final Object... arguments) {
        final Object listener = instantiate(className, arguments);
        if (listener instanceof ActionListener) {
            return (ActionListener) listener;
        }
        return event -> Main.showError("Could not run menu action: " + className);
    }

    private MouseListener mouseListener(final String className, final Object... arguments) {
        final Object listener = instantiate(className, arguments);
        if (listener instanceof MouseListener) {
            return (MouseListener) listener;
        }
        return EmptyMouseListener.INSTANCE;
    }

    private Object instantiate(final String className, final Object... arguments) {
        try {
            final Class<?> type = Class.forName("com.group_finity.mascot." + className);
            final Class<?>[] parameterTypes = new Class<?>[arguments.length + 1];
            final Object[] constructorArguments = new Object[arguments.length + 1];
            parameterTypes[0] = Main$1.class;
            constructorArguments[0] = this;
            for (int index = 0; index < arguments.length; index++) {
                parameterTypes[index + 1] = constructorType(arguments[index]);
                constructorArguments[index + 1] = arguments[index];
            }
            final Constructor<?> constructor = type.getDeclaredConstructor(parameterTypes);
            constructor.setAccessible(true);
            return constructor.newInstance(constructorArguments);
        } catch (final ReflectiveOperationException exception) {
            Main.showError("Could not create menu action:\n" + className);
            return null;
        }
    }

    private Class<?> constructorType(final Object argument) {
        if (argument instanceof JButton) {
            return JButton.class;
        }
        if (argument instanceof JPanel) {
            return JPanel.class;
        }
        return argument.getClass();
    }

    private JDialog currentDialog() {
        return (JDialog) fieldValue("form", this$0);
    }

    private void setCurrentDialog(final JDialog dialog) {
        setFieldValue("form", this$0, dialog);
    }

    private Frame mainFrame() {
        return (Frame) fieldValue("frame", null);
    }

    private Manager manager() {
        return (Manager) fieldValue("manager", this$0);
    }

    @SuppressWarnings("unchecked")
    private ArrayList<String> imageSets() {
        return (ArrayList<String>) fieldValue("imageSets", this$0);
    }

    private Object fieldValue(final String name, final Object target) {
        try {
            final Field field = Main.class.getDeclaredField(name);
            field.setAccessible(true);
            return field.get(target);
        } catch (final ReflectiveOperationException exception) {
            throw new IllegalStateException("Could not read Main." + name, exception);
        }
    }

    private void setFieldValue(final String name, final Object target, final Object value) {
        try {
            final Field field = Main.class.getDeclaredField(name);
            field.setAccessible(true);
            field.set(target, value);
        } catch (final ReflectiveOperationException exception) {
            throw new IllegalStateException("Could not update Main." + name, exception);
        }
    }

    private static final class EmptyMouseListener implements MouseListener {
        private static final EmptyMouseListener INSTANCE = new EmptyMouseListener();

        @Override
        public void mouseClicked(final MouseEvent event) {
        }

        @Override
        public void mousePressed(final MouseEvent event) {
        }

        @Override
        public void mouseReleased(final MouseEvent event) {
        }

        @Override
        public void mouseEntered(final MouseEvent event) {
        }

        @Override
        public void mouseExited(final MouseEvent event) {
        }
    }
}
