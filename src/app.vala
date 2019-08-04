using Gtk;


public class TextcodeApp : Gtk.Application {

    public struct MouseLoc {
        double x;
        double y;
    }

    private ViewWindow viewer;
    private DocOverview doc_overview;
    private Poppler.Document document;
    private PageAnalysis doc_analysis = null;
    private int index = 0;
    private int max_index;
    private bool main_mousebtn_pressed = false;
    private MouseLoc oldMouseLoc;
    private double mouseMoveSpeed = 0.8;

    public TextcodeApp () {
        Object (
            application_id: "textcodify",
            flags : ApplicationFlags.FLAGS_NONE
        );
    }

    private Button create_button () {
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
        box.pack_start (create_button (), false, false, 0);
        main_window.add (box);

        var title_bar = new TextcodeHeader (main_window);
        title_bar.open_file.connect (this.load_single_document);
        main_window.set_titlebar (title_bar);
        main_window.key_press_event.connect (this.handle_key_pressevent);
        main_window.key_release_event.connect (this.handle_key_releaseevent);
        viewer.scroll_event.connect (this.handle_viewer_scroll_event);
        viewer.button_release_event.connect (this.handle_clickup_event);
        viewer.button_press_event.connect (this.handle_clickdown_event);
        viewer.motion_notify_event.connect (this.handle_move_event);
        main_window.show_all ();
    }

    // ---- Input event handling ----

    private bool handle_key_pressevent (Gdk.EventKey k) {
        // Moving Pages
        if (k.keyval == Gdk.Key.Left) {
            this.previous_page ();
        } else if (k.keyval == Gdk.Key.Right) {
            this.next_page ();
        } else if (k.keyval == Gdk.Key.Control_L) {
            viewer.set_active_zooming (true);
        } else if (k.keyval == Gdk.Key.Home) {
            this.start_page ();
        } else if (k.keyval == Gdk.Key.End) {
            this.end_page ();
        } else if (k.keyval == Gdk.Key.p) {
            this.analyze_page ();
        }
        return false;
    }

    private bool handle_key_releaseevent (Gdk.EventKey k) {
        if (k.keyval == Gdk.Key.Control_L) {
            viewer.set_active_zooming (false);
        }
        return false;
    }

    // TODO: couldnt hook key events on the viewer window
    // therefore all of the event handling is part of the
    // main app (not my preferred design)
    private bool handle_viewer_scroll_event (Gdk.EventScroll e) {
        if (e.direction == Gdk.ScrollDirection.DOWN) {
            viewer.zoom_up ();
        } else if (e.direction == Gdk.ScrollDirection.UP) {
            viewer.zoom_down ();
        } else if (e.direction == Gdk.ScrollDirection.SMOOTH) {
            double x_d;
            double y_d;
            e.get_scroll_deltas (out x_d, out y_d);
            viewer.smooth_zoom (-y_d);
        }
        return false;
    }

    private bool handle_clickup_event (Gdk.EventButton b) {
        // TODO: Also call the main word-finding process here
        if (b.button == Gdk.BUTTON_PRIMARY) {
            main_mousebtn_pressed = false;
        } else if (b.button == Gdk.BUTTON_SECONDARY) {
            if (this.doc_analysis != null) {
                MouseLoc docloc = this.viewer.convert_click_loc (b.x, b.y);
                string sometext = this.doc_analysis.get_closest_text (docloc.x, docloc.y);
                print (@"txt: $sometext");
            } else {
                print ("Page has not been analyzed\n");
            }
        }
        return false;
    }

    private bool handle_clickdown_event (Gdk.EventButton b) {
        if (b.button == Gdk.BUTTON_PRIMARY) {
            main_mousebtn_pressed = true;
        }
        return false;
    }

    private bool handle_move_event (Gdk.EventMotion m) {
        if (main_mousebtn_pressed) {
            viewer.adjust_location (mouseMoveSpeed * (m.x - oldMouseLoc.x), mouseMoveSpeed * (m.y - oldMouseLoc.y));
            // TODO: Turning it around is more natural (hand tool) but _VERY_ janky
        }
        oldMouseLoc = MouseLoc () {
            x = m.x,
            y = m.y
        };
        return false;
    }

    // ---- ----

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

    private void analyze_page () {
        this.doc_analysis = new PageAnalysis (this.document.get_page (this.index));
    }

    private void next_page () {
        if (index < max_index) {
            index++;
            viewer.render_page.begin (this.document.get_page (this.index));
            this.doc_analysis = null;
        }
    }

    private void previous_page () {
        if (index > 0) {
            index--;
            viewer.render_page.begin (this.document.get_page (this.index));
            this.doc_analysis = null;
        }
    }

    private void start_page () {
        index = 0;
        viewer.render_page.begin (this.document.get_page (this.index));
    }

    private void end_page () {
        index = max_index;
        viewer.render_page.begin (this.document.get_page (this.index));
    }
}
