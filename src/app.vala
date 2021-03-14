using Gtk;


public class TextcodeApp : Gtk.Application {

    public struct MouseLoc {
        double x;
        double y;
    }

    // Interface objects
    private Gtk.ApplicationWindow main_window;
    private ViewWindow viewer;
    private DocOverview doc_overview;
    private StorageController storage_controller;
    private AnnotationOverview anno_overview;
    private AnnotationController anno_controller;
    private PageAnalysis doc_analysis = null;
    // Added App state
    private Poppler.Document ? document = null;
    private int document_db_id = -1;
    private int index = 0;
    private int max_index;
    private bool main_mousebtn_pressed = false;
    private MouseLoc oldMouseLoc;
    private double mouseMoveSpeed = 0.8;
    // Multi doc state
    private bool single_doc_mode;
    private Gee.HashMap<string, string> doc_name_loc_map;
    private string ? last_retrieved;

    public TextcodeApp () {
        Object (
            application_id: "dev.hillman.textcodify",
            flags : ApplicationFlags.FLAGS_NONE
        );
        this.anno_controller = new AnnotationController (12);
        this.storage_controller = new StorageController ();
    }

    protected override void activate () {
        main_window = new Gtk.ApplicationWindow (this);
        doc_overview = new DocOverview ();
        anno_overview = new AnnotationOverview (this.anno_controller.get_current_state ());
        this.anno_controller.set_selection_ref (anno_overview.get_selection ());
        doc_overview.doc_selection_changed.connect (updated_doc_selection);

        main_window.default_height = 600;
        main_window.default_width = 800;
        main_window.title = "textcodify";
        main_window.window_position = WindowPosition.CENTER;
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
        anno_overview.remove_annotation_item.clicked.connect (
            this.anno_controller.remove_current_selection
        );
        main_window.add (box);

        var title_bar = new TextcodeHeader (main_window);
        title_bar.open_file.connect (this.load_single_document);
        title_bar.open_folder.connect (this.load_folder);
        title_bar.store_sqlite.connect (this.save_annotations);
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
        } else if (k.keyval == Gdk.Key.r) {
            anno_controller.remove_current_selection ();
        } else if (k.keyval == Gdk.Key.a) {
            this.new_annotation_dialog ();
        } else if (k.keyval == Gdk.Key.g) {
            print ("g pressed \n");
            this.save_annotations ();
        }
        main_window.set_focus (viewer);
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
                PageAnalysis.TextAnnotation anno = this.doc_analysis.get_closest_text (
                    docloc.x, docloc.y
                );
                this.anno_controller.add_annotation (
                    index, anno.annotation, anno.full_line
                );
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

    /**
     * Convert a string with a path to just the filename
     * without the suffix
     */
    private static string get_filename (string filepath) {
        string[] loc_parts = filepath.split ("/");
        string name = loc_parts[loc_parts.length - 1];
        string[] name_parts = name.split (".");
        return name_parts[0];
    }

    /**
     * Load the document in storage, reset any annotations found
     * there and set viewer state
     */
    private void load_backendstate_document (string docloc) {
        anno_controller.clear_store ();
        StorageController.LoadedDoc doc_plus_id = storage_controller.load_doc (docloc);
        document = doc_plus_id.doc;
        document_db_id = doc_plus_id.doc_id;
        index = 0;
        max_index = document.get_n_pages () - 1;
        single_doc_mode = true;
        get_annotations (document_db_id);
        anno_overview.set_model (anno_controller.get_current_state ());
        anno_controller.set_selection_ref (anno_overview.get_selection ());

        viewer.render_page.begin (this.document.get_page (this.index));
    }

    /**
     * Start annotating a single document
     */
    private void load_single_document (string docloc) {
        load_backendstate_document (docloc);

        doc_overview.clear_docs ();
        string name = get_filename (docloc);
        doc_overview.add_doc_w_pages (name, document.get_n_pages ());
        doc_overview.select_first_row ();

        this.analyze_page ();
    }

    /**
     * Prepares the multi-doc-state `doc_name_loc_map` by loading in all
     * pdf files in the given directory path.
     */
    private bool setup_documents (string docfolderloc) {
        doc_name_loc_map = new Gee.HashMap<string, string>();
        if (!FileUtils.test (docfolderloc, FileTest.IS_DIR)) {
            printerr ("Selected location is not a folder\n");
            return false;
        }
        try {
            Dir dir = Dir.open (docfolderloc, 0);
            string ? filename = null;

            while ((filename = dir.read_name ()) != null) {
                string path = Path.build_filename (docfolderloc, filename);

                if (FileUtils.test (path, FileTest.IS_REGULAR)) {
                    if (path.has_suffix (".pdf")) {
                        string filename_wo_suffix = get_filename (path);
                        doc_name_loc_map.set (filename_wo_suffix, path);
                    }
                }
            }
        } catch (FileError err) {
            printerr (err.message);
            return false;
        }
        return true;
    }

    // 2nd load button will setup a full folder
    private void load_folder (string docfolderloc) {
        bool setup_success = setup_documents (docfolderloc);
        if (!setup_success) {
            printerr ("Loading directory unsuccessful\n");
            return;
        }
        doc_overview.clear_docs ();

        bool first = true;
        string ? loadfirst = null;

        foreach (string key in doc_name_loc_map.keys) {
            if (first == true) {
                loadfirst = key;
                first = false;
            }
            doc_overview.add_doc (key);
        }
        doc_overview.select_first_row ();
        load_folders_document (loadfirst);
    }

    // load string from map
    private void load_folders_document (string keyname) {
        if (!doc_name_loc_map.has_key (keyname)) {
            printerr ("Unknown folder filename (key)\n");
            return;
        }
        string filepath = doc_name_loc_map.get (keyname);
        load_backendstate_document (filepath);
        doc_overview.update_current_pages (document.get_n_pages ());
        last_retrieved = keyname;
        this.analyze_page ();
    }

    private void updated_doc_selection () {
        if (last_retrieved == null) {
            // Wait for the first selection to complete
            return;
        }
        string selected_keyname = doc_overview.get_name_current_selection ();
        if (selected_keyname != last_retrieved) {
            load_folders_document (selected_keyname);
        }
    }

    private void analyze_page () {
        this.doc_analysis = new PageAnalysis (this.document.get_page (this.index));
    }

    // ---  ---

    /**
     * Create a pop-up dialog for a new annotation type
     */
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

    /**
     * Custom response signal-connection for the new annotation
     * dialog
     */
    private void new_annotation_reaction (Dialog diag, int resp) {
        if (resp == ResponseType.OK) {
            Box content = diag.get_content_area ();
            List<weak Widget> widgets = content.get_children ();
            Entry field_output = (Entry) widgets.nth_data (1);
            this.anno_controller.add_annotation_type (field_output.text);
        }
        diag.destroy ();
    }

    /**
     * (Re)load annotations previously stored for current document
     *  */
    private void get_annotations (int db_doc_id) {
        Gtk.TreeStore inmemAnno = anno_controller.get_current_state ();
        storage_controller.get_annotations_from_db (inmemAnno, db_doc_id);
    }

    /**
     * Save all stored annotations using the storage-controller
     */
    private void save_annotations () {
        if ((document != null) && (document_db_id > 0)) {
            Gtk.TreeStore inmemAnno = anno_controller.get_current_state ();
            storage_controller.store_annotations_to_db (document_db_id, inmemAnno, true);
        }
    }

    private void next_page () {
        if (index < max_index) {
            index++;
            viewer.render_page.begin (document.get_page (this.index));
            this.analyze_page ();
        }
    }

    private void previous_page () {
        if (index > 0) {
            index--;
            viewer.render_page.begin (document.get_page (this.index));
            this.analyze_page ();
        }
    }

    private void start_page () {
        index = 0;
        viewer.render_page.begin (document.get_page (this.index));
        this.analyze_page ();
    }

    private void end_page () {
        index = max_index;
        viewer.render_page.begin (document.get_page (this.index));
        this.analyze_page ();
    }
}
