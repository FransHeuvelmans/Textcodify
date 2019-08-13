using Poppler;

public class StorageController {

    private static string password = "";

    public static Document load_doc(string loc) {
        Document doc;
        try {
            doc = new Document.from_file (
                Filename.to_uri (loc), password);
        } catch (GLib.Error e) {
            error ("%s", e.message);
        }
        return doc;
    }

}