using Gtk;


public class TextcodeApp : Gtk.Application {

    public struct MouseLoc {
        double x;
        double y;
    }

    private Gtk.ApplicationWindow main_window;
    private ViewWindow viewer;
    private DocOverview doc_overview;
    private AnnotationOverview anno_overview;
    private AnnotationController anno_controller;
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
        this.anno_controller = new AnnotationController (12);
    }

    protected override void activate () {
        main_window = new Gtk.ApplicationWindow (this);
        doc_overview = new DocOverview ();
        anno_overview = new AnnotationOverview (this.anno_controller.get_current_state ());
        this.anno_controller.set_selection_ref (anno_overview.get_selection ());
        main_window.default_height = 600;
        main_window.default_width = 800;
        main_window.title = "textcodify";
        main_window.window_position = WindowPosition.CENTER;
        main_window.destroy.connect (Gtk.main_quit);
        main_window.key_press_event.connect (this.handle_key_pressevent);
        main_window.key_release_event.connect (this.handle_key_releaseevent);

        Gtk.Box box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 5);

        box.pack_start (doc_overview.create_overview (), false, false, 0);
        doc_overview.l_button.clicked.connect (this.previous_page);
        doc_overview.r_button.clicked.connect (this.next_page);

        viewer = new ViewWindow ();
        viewer.add_events (Gdk.EventMask.ALL_EVENTS_MASK);
        box.pack_start (viewer, true, true, 0);
        viewer.scroll_event.connect (this.handle_viewer_scroll_event);
        viewer.button_release_event.connect (this.handle_clickup_event);
        viewer.button_press_event.connect (this.handle_clickdown_event);
        viewer.motion_notify_event.connect (this.handle_move_event);

        box.pack_start (anno_overview.create_overview (), false, false, 0);
        anno_overview.new_annotation_type.clicked.connect (
            this.new_annotation_dialog
        );
        main_window.add (box);

        var title_bar = new TextcodeHeader (main_window);
        title_bar.open_file.connect (this.load_single_document);
        main_window.set_titlebar (title_bar);

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
        } else if (k.keyval == Gdk.Key.w) {
            this.anno_controller.add_annotation (1, "onnat1");
            print ("annot added\n");
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
        document = StorageController.load_doc (docloc);
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

    private void new_annotation_dialog () {
        var diag_flags = DialogFlags.DESTROY_WITH_PARENT | DialogFlags.MODAL;
        var diag = new Dialog.with_buttons (
            "New annotation type",
            main_window, diag_flags,
            "ok", ResponseType.OK,
            "no", ResponseType.NO
        );
        diag.default_width = 400;
        Box content = diag.get_content_area ();
        var entry_label = new Label ("Annotation name:");
        content.pack_start (entry_label, false, false, 0);
        var entry_field = new Entry ();
        entry_field.text = "annotation1";
        content.pack_start (entry_field, false, false, 0);
        diag.response.connect (this.new_annotation_reaction);
        diag.show_all ();
    }

    private void new_annotation_reaction (Dialog diag, int resp) {
        if (resp == ResponseType.OK) {
            Box content = diag.get_content_area ();
            List<weak Widget> widgets = content.get_children ();
            Entry field_output = (Entry) widgets.nth_data(1);
            this.anno_controller.add_annotation_type (field_output.text);
        }
        diag.destroy ();
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
