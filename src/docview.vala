using Gtk;

public class DocOverview {
    private Box button_box;
    public Button l_button { get; private set; }
    public Button r_button { get; private set; }
    public signal void doc_selection_changed ();

    private TreeView tree_view;
    private Gtk.ListStore store;
    private int maxDocNameLength = 10;

    public DocOverview () {
        button_box = new Box (Orientation.HORIZONTAL, 2);
        l_button = new Button.from_icon_name ("go-previous", IconSize.BUTTON);
        r_button = new Button.from_icon_name ("go-next", IconSize.BUTTON);
        button_box.pack_start (l_button, true, true, 0);
        button_box.pack_end (r_button, true, true, 0);

        tree_view = new TreeView ();
        store = new Gtk.ListStore (2, typeof (string), typeof (int));
        tree_view.set_model (store);
        tree_view.insert_column_with_attributes (-1, "Doc", new CellRendererText (), "text", 0);
        tree_view.insert_column_with_attributes (-1, "Pages", new CellRendererText (), "text", 1);

        TreeSelection selection = tree_view.get_selection ();
        selection.changed.connect ((e) => doc_selection_changed ());
    }

    public Box create_overview () {
        var box = new Box (Orientation.VERTICAL, 5);
        box.pack_start (button_box, false, false, 0);
        box.pack_end (tree_view, true, true, 0);

        return box;
    }

    /**
     * Add a document to the list and set it's number of pages
     * in one go.
     */
    public void add_doc_w_pages (string name, int pages) {
        TreeIter insert_iter;
        store.append (out insert_iter);
        string showName;
        if (name.length > maxDocNameLength) {
            showName = name[0 : maxDocNameLength];
        } else {
            showName = name;
        }
        store.set (insert_iter, 0, showName, 1, pages, -1);
    }

    public void add_doc (string name) {
        TreeIter insert_iter;
        store.append (out insert_iter);
        store.set (insert_iter, 0, name, -1);
    }

    public void select_first_row () {
        TreeSelection selection = tree_view.get_selection ();
        TreeIter first_iter;
        store.get_iter_first (out first_iter);
        selection.select_iter (first_iter);
    }

    /**
     * Set the amount of pages for the currenly selected file
     */
    public void update_current_pages (int pages) {
        TreeSelection selection = tree_view.get_selection ();
        TreeIter selected;
        TreeModel model;
        bool find = selection.get_selected (out model, out selected);
        if (!find) {
            printerr ("Could not find currently selected document?");
        }
        store.set (selected, 1, pages, -1);
    }

    public string get_name_current_selection () {
        TreeSelection selection = tree_view.get_selection ();
        TreeIter selected;
        TreeModel model;
        bool find = selection.get_selected (out model, out selected);
        if (!find) {
            printerr ("Could not find currently selected document?");
        }
        string selection_name;
        store.get (selected, 0, out selection_name);
        return selection_name;
    }

    /**
     * Clear all documents in the list
     */
    public void clear_docs () {
        store.clear ();
    }
}

