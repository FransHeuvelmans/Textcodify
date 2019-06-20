using Gtk;

public class TextcodeHeader : HeaderBar {
    public ApplicationWindow main_window { get; private set; }

    public signal void open_file (string file);
    // For now disable folder -> feature for later
    //  public signal void open_folder (string folder);

    public TextcodeHeader (ApplicationWindow window) {
        main_window = window;
        show_close_button = true;

        var open_single_doc_button = new Button.from_icon_name (
            "document-open", IconSize.LARGE_TOOLBAR);
        open_single_doc_button.valign = Align.CENTER;
        open_single_doc_button.clicked.connect (open_single_doc_clicked);
        //  var open_folder_button = new Button.from_icon_name (
        //      "folder-open", IconSize.LARGE_TOOLBAR);
        //  open_folder_button.valign = Align.CENTER;
        var menu_button = new Button.from_icon_name (
            "open-menu", IconSize.LARGE_TOOLBAR);
        menu_button.valign = Align.CENTER;

        pack_start (open_single_doc_button);
        //  pack_start (open_folder_button);
        pack_end (menu_button);
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
}