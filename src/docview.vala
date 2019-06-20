using Gtk;

public class DocOverview {
    private Box button_box;
    public Button l_button { get; private set; }
    public Button r_button { get; private set; }

    private TreeView tree_view;
    private Gtk.ListStore store;

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
    }

    public Box create_overview () {
        var box = new Box (Orientation.VERTICAL, 5);
        box.pack_start (button_box, false, false, 0);
        box.pack_end (tree_view, true, true, 0);

        return box;
    }

    public void add_doc (string name, int pages) {
        TreeIter insert_iter;
        store.append (out insert_iter);
        store.set (insert_iter, 0, name, 1, pages);
    }

    public void clear_docs () {
        store.clear();
    }
}

