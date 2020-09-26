using Poppler;
using Sqlite;
using Gee;

public class StorageController {

    public struct LoadedDoc {
        Document doc;
        int doc_id;
    }

    public struct AnnotationDb {
        int page_id;
        int page_nr;
        string anno;
        string anno_full_line;
        string anno_type;
    }

    private string doc_password;

    private Database? current_db = null;

    public StorageController () {
        doc_password = "";
    }

    public LoadedDoc load_doc (string loc) {
        File doc_file = File.new_for_path (loc);
        Document doc;
        try {
            doc = new Document.from_file (
                doc_file.get_uri (), doc_password);
        } catch (GLib.Error e) {
            error ("%s", e.message);
        }
        var db_dir = doc_file.get_parent ();
        var db_loc = db_dir.get_child ("sqlitetest.db").get_path ();
        if (current_db == null) {
            setup_db (db_loc);
        }
        int doc_id = sync_new_document_to_db (doc_file, doc); 
        // Get doc id here and give it to the app to store next to the document itself
        // then when synchronizing, pass it to the store-function
        var docout = LoadedDoc () {
            doc = doc,
            doc_id = doc_id
        };
        return docout;
    }

    /* Setup a new DB if none exists and load it with the right tables */
    private void setup_db (string location) {
        bool f = FileUtils.test (location, FileTest.IS_REGULAR);
        int rc;
        rc = Database.open (location, out current_db);
        if (rc != Sqlite.OK) {
            stderr.printf ("SQLite: Can't open database: %d: %s\n",
                           current_db.errcode (), current_db.errmsg ());
        }
        // If it didn't exist before, create the right tables
        if (!f) {
            setup_tables (current_db);
        }
    }

    /* Create the right tables in the DB (helper for setup_db)*/
    private static void setup_tables (Database db) {
        string[] stmts_str = { """
            CREATE TABLE documents (
                id          INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                hash        INT                     NOT NULL,
                name        TEXT,
                location    TEXT                    NOT NULL
            );""", """
            CREATE TABLE pages (
                id          INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                doc_id      INT                     NOT NULL,
                page_nr     INT                     NOT NULL,
                text        TEXT,
                FOREIGN KEY (doc_id)
                    REFERENCES documents (id)
            );""", """
            CREATE TABLE annotations (
                id          INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                page_id     INT                     NOT NULL,
                page_nr     INT                     NOT NULL,
                anno        TEXT                    NOT NULL,
                anno_full_line      TEXT            NOT NULL,
                anno_type   TEXT                    NOT NULL,
                FOREIGN KEY (page_id)
                    REFERENCES pages (id)
            );""" };
        int ec;
        for (int i = 0; i < 3; i++) {
            ec = db.exec (stmts_str[i], null);
            if (ec != Sqlite.OK) {
                stderr.printf ("SQLite error setup_tables %d: %s\n", db.errcode (), db.errmsg ());
            }
        }
    }

    /**
     * Store general document info in the db
     * */
    private int sync_new_document_to_db (File doc_loc, Document doc) {
        int doc_id = -1;
        if (current_db == null) {
            return doc_id;
        }
        uint doc_hash = doc_loc.hash ();
        string doc_title = doc.title;
        if (doc_hash == 0) {
            printerr ("Err: File hash == 0");
        }
        if (doc_title == null) {
            doc_title = "";
        }
        doc_id = this.check_doc_in_db (doc_hash, doc_title);
        print (@"debug: Already loaded? $doc_id\n");

        if (doc_id == -1) {
            string doc_fullloc = doc_loc.get_path ();
            string inquery = ("INSERT INTO documents (hash, name, location) " +
                @"VALUES($doc_hash, ?001, ?002);");
            Statement document_statement;
            int rc = current_db.prepare_v2 (inquery, inquery.length, out document_statement);
            if (rc != Sqlite.OK) {
                printerr ("SQL error document_insert %d: %s\n", rc, current_db.errmsg ());
                return doc_id;
            }
            int doc_title_pos = document_statement.bind_parameter_index ("?001");
            int doc_fullloc_pos = document_statement.bind_parameter_index ("?002");
            document_statement.bind_text (doc_title_pos, doc_title);
            document_statement.bind_text (doc_fullloc_pos, doc_fullloc);
            rc = document_statement.step ();
            if (rc != Sqlite.DONE) {
                printerr ("SQL runerror document_insert %d: %s\n", rc, current_db.errmsg ());
                return doc_id;
            }
            document_statement.reset ();

            int64 temp_id = current_db.last_insert_rowid ();
            doc_id = (int) temp_id;

            /* Always assumes that with a new document, the new pages
             * are stored. */
            string inpagequery = "INSERT INTO pages (doc_id, page_nr, text)" +
             "VALUES(?001, ?002, ?003);";
            Statement page_statement;
            rc = current_db.prepare_v2 (inpagequery, inpagequery.length, out page_statement);
            if (rc != Sqlite.OK) {
                printerr ("SQL error page_insert %d: %s\n", rc, current_db.errmsg ());
                return doc_id;
            }
            int doc_id_pos = page_statement.bind_parameter_index ("?001");
            int page_nr_pos = page_statement.bind_parameter_index ("?002");
            int text_pos = page_statement.bind_parameter_index ("?003");
            
            var nr_pages = doc.get_n_pages ();
            Page page;
            string pagetxt;
            for (int i = 0; i < nr_pages; i++) {
                page = doc.get_page (i);
                pagetxt = page.get_text ();
                page_statement.bind_int (doc_id_pos, doc_id);
                page_statement.bind_int (page_nr_pos, i);
                page_statement.bind_text (text_pos, pagetxt);
                rc = page_statement.step ();
                if (rc != Sqlite.DONE) {
                    printerr ("SQL runerror page_insert %d for page %d: %s\n", rc, i, current_db.errmsg ());
                    return doc_id;
                }
                page_statement.reset ();

                print (@"debug: Entered page $i\n");
            }
        }
        print (@"debug: Loaded document $doc_id\n");
        
        return doc_id;
    }

    /**
     * Check if a document has already been loaded in the db.
     * If one already exists returns id else -1
     * (Does not check if the location has changed and relies on hash)
     *  */
    private int check_doc_in_db (uint doc_hash, string doc_title) {
        Statement check_stmt;
        int found = -1;
        string query = @"SELECT id, hash, name FROM documents WHERE " +
            @"hash = '$doc_hash' AND name = '$doc_title';";
        int rc = current_db.prepare_v2 (query, query.length, out check_stmt, null);
        if (rc != Sqlite.OK) {
            printerr ("SQL error check_doc %d: %s\n", rc, current_db.errmsg ());
            return found;
        }
        rc = check_stmt.step ();
        switch (rc) {
            case Sqlite.DONE:
                break;
            case Sqlite.ROW:
                // column 0 holds the id
                found = check_stmt.column_int (0);
                break;
            default:
                printerr ("Error: %d, %s\n", rc, current_db.errmsg ());
                break;
        }
        return found;
    }

    // TODO: a separate function for getting a new document from the current database (if we
    // are handling multiple files) and make sure that app always gets the latest annotations
    // if loading a new document (either single-doc / multi-doc-folder setting)

    /**
     * For a particular document find all the id's for all the pages and return them in a
     * hashmap<page_nr, page_id>
     * */
    public HashMap<int, int> get_db_page_mapping (int db_doc_id) {
        var map = new HashMap<int, int> ();
        if (db_doc_id < 0) {
            // Don't expect id's < 0
            printerr ("faulty db mapping requested %d", db_doc_id);
            return map;
        }
        Statement pagemap_stmt;
        string query = "SELECT id, page_nr FROM pages WHERE " +
            @"doc_id = $db_doc_id;";
        int rc = current_db.prepare_v2 (query, query.length, out pagemap_stmt, null);
        if (rc != Sqlite.OK) {
            printerr ("SQL error pagemap %d: %s\n", rc, current_db.errmsg ());
            return map;
        }
        while (pagemap_stmt.step () == Sqlite.ROW) {
            int page_id = pagemap_stmt.column_int (0);
            int page_nr = pagemap_stmt.column_int (1);
            map.set (page_nr, page_id);
        }
        return map;
    }

    private void _cleandb(int db_doc_id) {
        const string query = """
        DELETE FROM annotations as an
        WHERE an.page_id in 
            (SELECT 
                p.id as page_id
            FROM pages p
            JOIN documents d
            ON p.doc_id = d.id
            WHERE d.id = ?001);""";
        Statement delete_anno_stmt;
        int rc = current_db.prepare_v2 (query, query.length, out delete_anno_stmt);
        if (rc != Sqlite.OK) {
            printerr ("SQL error anno_delete %d: %s\n", rc, current_db.errmsg ());
            return;
        }
        int doc_id_pos = delete_anno_stmt.bind_parameter_index ("?001");
        delete_anno_stmt.bind_int (doc_id_pos, db_doc_id);
        rc = delete_anno_stmt.step ();
        switch (rc) {
            case Sqlite.DONE:
                break;
            default:
                printerr ("Error: %d, %s\n", rc, current_db.errmsg ());
                break;
        }
        print ("Deleted old annotations\n");
        return;
    }

    /**
     * Store a list of annotations in the db
     */
    private int _anno2db (LinkedList<AnnotationDb?> annotations) {
        const string inannoquery = "INSERT INTO annotations (page_id, page_nr, anno, anno_full_line," +
        "anno_type) VALUES (?001, ?002, ?003, ?004, ?005)";
        Statement anno_insert_statement;
        int rc;
        rc = current_db.prepare_v2 (inannoquery, inannoquery.length, out anno_insert_statement);
        if (rc != Sqlite.OK) {
            printerr ("SQL error anno_insert %d: %s\n", rc, current_db.errmsg ());
            return -1;
        }
        int page_id_pos = anno_insert_statement.bind_parameter_index ("?001");
        int page_nr_pos = anno_insert_statement.bind_parameter_index ("?002");
        int anno_pos = anno_insert_statement.bind_parameter_index ("?003");
        int anno_full_line_pos = anno_insert_statement.bind_parameter_index ("?004");
        int anno_type_pos = anno_insert_statement.bind_parameter_index ("?005");
        int addedAnno = 0;
        foreach (AnnotationDb? anAnno in annotations) {
            if (anAnno != null) {
                anno_insert_statement.bind_int (page_id_pos, anAnno.page_id);
                anno_insert_statement.bind_int (page_nr_pos, anAnno.page_nr);
                anno_insert_statement.bind_text (anno_pos, anAnno.anno);
                anno_insert_statement.bind_text (anno_full_line_pos, anAnno.anno_full_line);
                anno_insert_statement.bind_text (anno_type_pos, anAnno.anno_type);
                rc = anno_insert_statement.step ();
                if (rc != Sqlite.DONE) {
                    printerr ("SQL runerror %d anno_insert for page %d: %s\n", rc, anAnno.page_nr, current_db.errmsg ());
                    return -1;
                }
                anno_insert_statement.reset ();
                addedAnno++;
            }
        }
        return addedAnno;
    }

    /**
     * Store the current annotations in the database
     * Modus denotes overwrite or append
     */
    public bool store_annotations_to_db (int db_doc_id, Gtk.TreeStore annotation_info, bool overwrite_modus) {
        /* if modus_overwrite -> first delete all annotations for this document_id
         * else append_modus -> add all new annotations but leave the old ones */
        if (overwrite_modus) {
            _cleandb (db_doc_id);
        }
        
        print ("Storing annotations");
        HashMap<int, int> pagemap = this.get_db_page_mapping (db_doc_id); // Add back in later
        LinkedList<AnnotationDb?> annotationsForDb = new LinkedList<AnnotationDb> ();
        // TODO: Can't use structs ?? (And too many things are still set to public where they don't need to)
        Gtk.TreeIter parent_iter;
        string annotation_type;
        Gtk.TreeIter child_iter;

        bool next_found_parent = annotation_info.get_iter_first (out parent_iter);
        while (next_found_parent) {
            annotation_info.get (parent_iter, 3, out annotation_type, -1);
            if (annotation_info.iter_has_child (parent_iter)) {
                bool next_found_child = annotation_info.iter_children (out child_iter, parent_iter);
                while (next_found_child) {
                    var storeAnno = AnnotationDb();
                    storeAnno.anno_type = annotation_type;
                    annotation_info.get (child_iter, 
                        2, out storeAnno.page_nr,
                        3, out storeAnno.anno,
                        4, out storeAnno.anno_full_line, -1);
                    if (pagemap.has_key(storeAnno.page_nr)) {
                        storeAnno.page_id = pagemap.get(storeAnno.page_nr);
                        annotationsForDb.add(storeAnno);
                    }
                    next_found_child = annotation_info.iter_next (ref child_iter);
                } 
                // next while loop to iterate over the child nodes
                // --> inside this loop we can first print the vals (and then turn that into something useful)
            }
            next_found_parent = annotation_info.iter_next (ref parent_iter);
        }
        int ins_res = _anno2db (annotationsForDb);
        if (ins_res > 0) {
            return true;
        }
        return false;
    }

    /**
     * Get all annotations from the DB for this document (id) and put them in the given TreeStore
     * */
    public void get_annotations_from_db (Gtk.TreeStore anno_store, int doc_id) {
        const string query = """
        SELECT
            an.page_nr,
            an.anno,
            an.anno_full_line,
            an.anno_type
        FROM annotations an
        WHERE an.page_id in 
            (SELECT 
                p.id as page_id
            FROM pages p
            JOIN documents d
            ON p.doc_id = d.id
            WHERE d.id = ?001)
        ORDER BY an.anno_type, an.page_nr;""";
        Statement get_anno_stmt;
        int rc = current_db.prepare_v2 (query, query.length, out get_anno_stmt);
        if (rc != Sqlite.OK) {
            printerr ("SQL error anno_retrieve %d: %s\n", rc, current_db.errmsg ());
            return;
        }
        int doc_id_pos = get_anno_stmt.bind_parameter_index ("?001");
        get_anno_stmt.bind_int (doc_id_pos, doc_id);

        string last_added_annotation_type = "";
        string full_annotation_type;
        string full_annotation;
        Gtk.TreeIter? tree_iter = null;
        Gtk.TreeIter anno_iter;
        while (get_anno_stmt.step () == Sqlite.ROW) {
            full_annotation_type = get_anno_stmt.column_text (3);
            if (full_annotation_type != last_added_annotation_type) {
                // need to add new type
                anno_store.append (out tree_iter, null);
                // TODO: Get max-strlen from proper place (or set Global)
                if (full_annotation_type.length > 12) {
                    anno_store.set (tree_iter, 0, full_annotation_type[0:12], 3, full_annotation_type, -1);
                } else {
                    anno_store.set (tree_iter, 0, full_annotation_type, 3, full_annotation_type, -1);
                }
                last_added_annotation_type = full_annotation_type;
            }
            if (tree_iter != null) {
                anno_store.append (out anno_iter, tree_iter);
            } else {
                // Shouldn't happen normally but for the compiler/edge cases
                anno_store.append (out anno_iter, null);
            }
            full_annotation = get_anno_stmt.column_text (1);
            // TODO: See other todo
            if (full_annotation.length > 12) {
                anno_store.set (
                    anno_iter, 
                    1, full_annotation[0:12],
                    2, get_anno_stmt.column_int (0), 
                    3, full_annotation, 
                    4, get_anno_stmt.column_text (2), 
                    -1
                );
            } else {
                anno_store.set (
                    anno_iter, 
                    1, full_annotation,
                    2, get_anno_stmt.column_int (0), 
                    3, full_annotation, 
                    4, get_anno_stmt.column_text (2), 
                    -1
                );
            }
        }
        return;
    }

}