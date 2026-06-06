package com.group_finity.mascot;

import com.group_finity.mascot.config.Configuration;

import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * Replacement for the original right-click "Follow Cursor" menu action.
 *
 * The original action sent every mascot in the image set into ChaseMouse. This
 * version affects only the clicked mascot and puts it into the existing
 * Dragged behavior, which keeps the sprite visually holding the pointer until
 * the user picks another behavior.
 */
class Mascot$7 implements ActionListener {
    private static final Logger log = Logger.getLogger(Mascot.class.getName());

    private final Mascot mascot;

    Mascot$7(final Mascot mascot) {
        this.mascot = mascot;
    }

    @Override
    public void actionPerformed(final ActionEvent event) {
        try {
            mascot.setDragging(false);
            mascot.setCursorPosition(null);

            final Configuration configuration = Main.getInstance().getConfiguration(mascot.getImageSet());
            mascot.setBehavior(configuration.buildBehavior("Dragged"));
        } catch (final Exception exception) {
            log.log(Level.SEVERE, "Could not hold mascot on pointer", exception);
            Main.showError("Could not make this stickfigure hold the pointer.\n" + exception.getMessage());
        }
    }
}
