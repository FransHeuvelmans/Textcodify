using Gtk;

public class TextcodeHeader : HeaderBar {
    public ApplicationWindow main_window { get; private set; }

    public signal void open_file (string file);
    public signal void open_folder (string folder);
    public signal void store_sqlite ();

    // For now disable folder -> feature for later
    // public signal void open_folder (string folder);

    public TextcodeHeader (ApplicationWindow window) {
        main_window = window;
        show_close_button = true;

        var open_single_doc_button = new Button.from_icon_name (
            "document-open", IconSize.LARGE_TOOLBAR);
        open_single_doc_button.valign = Align.CENTER;
        open_single_doc_button.clicked.connect (open_single_doc_clicked);
        var open_folder_button = new Button.from_icon_name (
            "folder-open", IconSize.LARGE_TOOLBAR);
        open_folder_button.valign = Align.CENTER;
        open_folder_button.clicked.connect (open_folder_clicked);
        var store_sqlite_button = new Button.from_icon_name (
            "media-floppy", IconSize.LARGE_TOOLBAR);
        store_sqlite_button.valign = Align.CENTER;
        store_sqlite_button.clicked.connect (save_to_db_clicked);

        pack_start (open_single_doc_button);
        pack_start (open_folder_button);
        pack_end (store_sqlite_button);
    }

    public void save_to_db_clicked () {
        store_sqlite ();
    }

    public void open_single_doc_clicked () {
        var file_chooser = new FileChooserDialog (
            "Open File", main_window, FileChooserAction.OPEN,
            "_Cancel", ResponseType.CANCEL,
            "_Open", ResponseType.ACCEPT);
        int run_result = file_chooser.run ();
        if (run_result == ResponseType.ACCEPT) {
            open_file (file_chooser.get_filename ());
        }
        file_chooser.destroy ();
    }

    public void open_folder_clicked () {
        var file_chooser = new FileChooserDialog (
            "Open Folder", main_window, FileChooserAction.SELECT_FOLDER,
            "_Cancel", ResponseType.CANCEL,
            "_Open", ResponseType.ACCEPT);
        int run_result = file_chooser.run ();
        if (run_result == ResponseType.ACCEPT) {
            open_folder (file_chooser.get_filename ());
        }
        file_chooser.destroy ();
    }
}