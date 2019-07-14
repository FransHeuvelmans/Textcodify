using Gtk;


public class TextcodeApp : Gtk.Application {

    private ViewWindow viewer;
    private DocOverview doc_overview;
    private Poppler.Document document;
    private int index = 0;
    private int max_index;

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
        doc_overview = new DocOverview ();
        main_window.default_height = 600;
        main_window.default_width = 800;
        main_window.title = "textcodify";
        main_window.window_position = WindowPosition.CENTER;
        main_window.destroy.connect (Gtk.main_quit);

        Gtk.Box box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 5);
        box.pack_start (doc_overview.create_overview (), false, false, 0);
        viewer = new ViewWindow ();
        viewer.add_events (Gdk.EventMask.ALL_EVENTS_MASK);
        doc_overview.l_button.clicked.connect (this.previous_page);
        doc_overview.r_button.clicked.connect (this.next_page);
        box.pack_start (viewer, true, true, 0);
        box.pack_start (createButton (), false, false, 0);
        main_window.add (box);

        var title_bar = new TextcodeHeader (main_window);
        title_bar.open_file.connect (this.load_single_document);
        main_window.set_titlebar (title_bar);
        main_window.key_press_event.connect (this.handle_key_event);
        // viewer.button_release_event.connect (this.handle_click_event);
        main_window.show_all ();
    }

    private bool handle_key_event (Gdk.EventKey k) {
        print ("c");
        if (k.keyval == Gdk.Key.Left) {
            this.previous_page ();
        } else if (k.keyval == Gdk.Key.Right) {
            this.next_page ();
        }
        return false;
    }

    // private bool handle_click_event (Gdk.EventButton b) {
    // double x_loc = b.x;
    // double y_loc = b.y;
    // print (@"Button pressed x: $x_loc , y: $y_loc");
    // return false;
    // }

    public static int main (string[] args) {
        var app = new TextcodeApp ();
        return app.run (args);
    }

    private void load_single_document (string docloc) {
        document = Controller.load_doc (docloc);
        index = 0;
        max_index = document.get_n_pages () - 1;
        viewer.render_page.begin (this.document.get_page (this.index));

        doc_overview.clear_docs ();
        string[] loc_parts = docloc.split ("/");
        string name = loc_parts[loc_parts.length - 1];
        string[] name_parts = name.split (".");
        name = name_parts[0];
        doc_overview.add_doc (name, document.get_n_pages ());
    }

    private void next_page () {
        if (index < max_index) {
            index++;
            viewer.render_page.begin (this.document.get_page (this.index));
        }
    }

    private void previous_page () {
        if (index > 0) {
            index--;
            viewer.render_page.begin (this.document.get_page (this.index));
        }
    }
}
