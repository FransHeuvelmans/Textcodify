using Cairo;
using Gtk;

public class ViewFrame : Frame {

// To store the document and the current page
    private Context context;
    private Image image;
    private bool image_set = false;
    private int width = 800;
    private int height = 600;

    public ViewFrame () {
        this.set_events (Gdk.EventMask.BUTTON_PRESS_MASK | Gdk.EventMask.KEY_PRESS_MASK);
        image = new Image ();
    }

    public void render_page (Poppler.Page page) {
        if (image_set) {
            remove (image);
        }
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
        page.render (this.context);
        Gdk.Pixbuf pixbuf = Gdk.pixbuf_get_from_surface (
            context.get_target (),
            0,
            0,
            width - 2,
            height - 2);
        image.set_from_pixbuf (pixbuf);

        this.add (image);
        image_set = true;
        this.show_all ();
    }

    private void set_size () {
        width = this.get_allocated_width ();
        height = this.get_allocated_height ();
    }
}