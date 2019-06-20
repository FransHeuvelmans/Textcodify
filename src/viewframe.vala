using Cairo;
using Gtk;

public class ViewFrame : Frame {

// To store the document and the current page
    private Poppler.Document document;
    private Context context;
    private Image image;
    private bool image_set = false;
    private int width = 800;
    private int height = 600;
    private int index = 0;
    private int max_index;
    private string password = "";

    public ViewFrame () {
        this.set_events (Gdk.EventMask.BUTTON_PRESS_MASK | Gdk.EventMask.KEY_PRESS_MASK);
        image = new Image ();
    }

    public void set_document (string file_name) {
        try {
            this.document = new Poppler.Document.from_file (
                Filename.to_uri (file_name), password);
        } catch (Error e) {
            error ("%s", e.message);
        }
        if (image_set) {
            remove (image);
        }
        index = 0;
        max_index = document.get_n_pages () - 1;
        render_page ();

        this.add (image);
        image_set = true;
        this.show_all ();
    }

    private void render_page () {
        set_size ();
        //  this.set_label (@"Page $index");
        // new Cairo surface
        var surface = new ImageSurface (
            Format.ARGB32, width, height);
        context = new Context (surface);

        // Clear the Cairo surface to white
        context.set_source_rgb (255, 255, 255);
        context.paint ();
        // Output the PDF page to the Cairo surface,
        // then get a pixbuf, then an image, from this surface
        Poppler.Page page = this.document.get_page (this.index);
        page.render (this.context);
        Gdk.Pixbuf pixbuf = Gdk.pixbuf_get_from_surface (
            context.get_target (),
            0,
            0,
            width,
            height);
        image.set_from_pixbuf (pixbuf);
    }

    public void next_page () {
        if (index < max_index) {
            index++;
            render_page ();
        }
    }

    public void previous_page () {
        if (index > 0) {
            index--;
            render_page ();
        }
    }

    private void set_size () {
        width = this.get_allocated_width ();
        height = this.get_allocated_height ();
    }
}