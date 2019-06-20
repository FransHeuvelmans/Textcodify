using Gtk;


public class TextcodeApp : Gtk.Application {

    private ViewFrame viewer;

    public TextcodeApp () {
        Object (
            application_id: "textcodify",
            flags : ApplicationFlags.FLAGS_NONE
        );
    }

    private Button createButton () {
        var button = new Button.with_label ("Click me!");
        button.clicked.connect (() => {
            button.label = "What has happened";
        });
        return button;
    }

    protected override void activate () {
        var main_window = new Gtk.ApplicationWindow (this);
        var doc_overview = new DocOverview ();
        main_window.default_height = 600;
        main_window.default_width = 800;
        main_window.title = "textcodify";
        main_window.window_position = WindowPosition.CENTER;
        main_window.destroy.connect (Gtk.main_quit);

        Gtk.Box box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 5);
        box.pack_start (doc_overview.create_overview (), false, false, 0);
        viewer = new ViewFrame ();
        doc_overview.l_button.clicked.connect (viewer.previous_page);
        doc_overview.r_button.clicked.connect (viewer.next_page);
        box.pack_start (viewer, true, true, 0);
        box.pack_start (createButton (), false, false, 0);
        main_window.add (box);

        var title_bar = new TextcodeHeader (main_window);
        title_bar.open_file.connect (viewer.set_document);
        main_window.set_titlebar (title_bar);
        main_window.key_press_event.connect (this.handle_key_event);
        main_window.show_all ();
    }

    private bool handle_key_event (Gdk.EventKey k) {
        if (k.keyval == Gdk.Key.Left) {
            viewer.previous_page ();
        } else if (k.keyval == Gdk.Key.Right) {
            viewer.next_page ();
        }
        return false;
    }

    public static int main (string[] args) {
        var app = new TextcodeApp ();
        return app.run (args);
    }
}
