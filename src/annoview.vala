using Gtk;

public class AnnotationOverview {

    public Button new_annotation_type { get; private set; }
    private TreeView tree_view;

    public AnnotationOverview (TreeModel model) {
        this.new_annotation_type = new Button.from_icon_name ("list-add", IconSize.BUTTON);
        this.tree_view = new TreeView.with_model (model);
        this.tree_view.set_enable_search (false);
        this.tree_view.insert_column_with_attributes(-1, "Type", new CellRendererText (), "text", 0);
        this.tree_view.insert_column_with_attributes(-1, "Anno", new CellRendererText (), "text", 1);
        this.tree_view.insert_column_with_attributes(-1, "Page", new CellRendererText (), "text", 2);
    }

    public Box create_overview () {
        var box = new Box (Orientation.VERTICAL, 5);
        box.pack_start (this.new_annotation_type, false, false, 0);
        box.pack_end (this.tree_view, true, true, 0);
        return box;
    }

    public void set_model(TreeModel model) {
        this.tree_view.set_model (model);
    }

    public TreeSelection get_selection () {
        var sel = this.tree_view.get_selection ();
        sel.set_mode (SelectionMode.SINGLE);
        return sel;
    }
}