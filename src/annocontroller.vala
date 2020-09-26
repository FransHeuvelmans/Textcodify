using Gtk;
// using Gee;

public class AnnotationController {


    private TreeStore store;
    private TreeSelection selection_ref = null; // Ref to the UI
    private int max_strlen;


    public AnnotationController (int max_strlen) {
        
        this.clear_store();
        this.max_strlen = max_strlen;
        /**
         * For now on reset (new document) build a new controller
         */
    }

    public void set_selection_ref (TreeSelection selection) {
        this.selection_ref = selection;
    }

    /* Clear the store and create a fresh one 
    (Whenever called, reset the selection ref for the
    new store to function normally)*/
    public void clear_store() {
        store = new Gtk.TreeStore (
            5,
            typeof (string),    // Annotation type
            typeof (string),    // Annotation (abbreviated)
            typeof (int),       // Page
            typeof (string),    // Annotation or Annotation type (in full)
            typeof (string)     // Full-line of annotation
        );
        selection_ref = null;
    }

    // public void load_store (SomeStoreFormat Gee.bla)

    /**
     * Add an annotation to the Treestore
     * */
    public bool add_annotation (int page, string txt, string line_text) {
        if (this.selection_ref == null) {
            print ("Set selection reference first!");
            return false;
        }
        // Get annotation type info from TreeSelection
        TreeIter insert_iter;
        TreeIter ? parent_iter = this.get_parent_iter_selection ();
        if (parent_iter == null) {
            return false;
        }
        store.append (out insert_iter, parent_iter);
        string annot_text;
        if (txt.length > max_strlen) {
            annot_text = txt[0 : max_strlen];
        } else {
            annot_text = txt;
        }
        store.set (insert_iter, 1, annot_text, 2, page, 3, txt, 4, line_text, -1);
        return true;
    }

    /**
     * Add a new annotation type as a top level
     */
    public bool add_annotation_type (string new_annotation_type) {
        if (this.anot_type_exists (new_annotation_type)) {
            return false;
        }
        Gtk.TreeIter insert_iter;
        store.append (out insert_iter, null);
        string type_name;
        if (new_annotation_type.length > max_strlen) {
            type_name = new_annotation_type[0 : max_strlen];
        } else {
            type_name = new_annotation_type;
        }
        store.set (insert_iter, 0, type_name, 3, new_annotation_type, -1);
        return true;
    }

    /**
     * Check if a annotation-type is already in the store
     */
    private bool anot_type_exists (string new_annotation_type) {
        TreeIter next_iter;
        bool iter_retrieved = store.get_iter_first (out next_iter);
        if (!iter_retrieved) {
            return false;
        }
        string old_annotation_type = "replaced_by_type";
        store.get (next_iter, 0, out old_annotation_type, -1);
        if (new_annotation_type == old_annotation_type) {
            return true;
        }
        while (store.iter_next (ref next_iter)) {
            store.get (next_iter, 0, out old_annotation_type, -1);
            if (new_annotation_type == old_annotation_type) {
                return true;
            }
        }
        return false;
    }

    /**
     * Get the top_level TreeIter object (most often the Annotation Type TreeIter)
     */
    private TreeIter ? get_parent_iter_selection () {
        // Assume single output
        TreeIter out_iter;
        TreeModel model;
        bool is_select = this.selection_ref.get_selected (out model, out out_iter);
        if (!is_select) {
            return null;
        }
        string type_val = "replaced_by_parent_type";
        store.get (out_iter, 0, type_val, -1);
        if (type_val.length > 0) {
            // if larger than 0 -> it has been set, is top level
            return out_iter;
        }
        TreeIter parent_iter;
        var succ = store.iter_parent (out parent_iter, out_iter);
        if (succ) {
            return parent_iter;
        } else {
            return null;
        }
    }

    /**
     * Remove the currently selected (through set selection ref)
     * item (TreeIter)
     */
    public void remove_current_selection () {
        TreeIter out_iter;
        TreeModel model;
        bool is_select = this.selection_ref.get_selected (out model, out out_iter);
        if (is_select) {
            this.store.remove (ref out_iter);
        }
    }

    /**
     * Retrieve the current Treestore for viewing
     */
    public TreeStore get_current_state () {
        return this.store;
    }
}