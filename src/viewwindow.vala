using Cairo;
using Gtk;

public class ViewWindow : ScrolledWindow {

// To store the document and the current page
    private Image image;
    private EventBox eventBox;
    private double zoom = 1;
    private int marginSpace = 5;
    private bool busyZooming = false;
    private Poppler.Page lastRenderedPage;

    public ViewWindow () {
        base.add_events (Gdk.EventMask.ALL_EVENTS_MASK);
        this.add_events (Gdk.EventMask.ALL_EVENTS_MASK);
        image = new Image ();
        eventBox = new EventBox ();
        eventBox.add_events (Gdk.EventMask.ALL_EVENTS_MASK);
        eventBox.add (image);
        this.add (eventBox);
        this.set_valign (Gtk.Align.CENTER);
        this.key_press_event.connect (handle_key_press_event);
        this.key_release_event.connect (handle_key_release_event);
        this.scroll_event.connect (handle_scroll_event);
        this.show_all ();
    }

    public async void render_page (Poppler.Page page) {
        // Getting the right size
        double page_width;
        double page_height;
        page.get_size (out page_width, out page_height);
        int width = (int) (zoom * page_width);
        int height = (int) (zoom * page_height);

        // Adjust the scrolled-window
        this.width_request = (int) page_width + marginSpace;
        this.height_request = (int) page_height + marginSpace;
        this.set_valign (Gtk.Align.CENTER);
        this.set_halign (Gtk.Align.CENTER);

        // Creating a surface/context to write the page to
        var surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, width, height);
        var context = new Cairo.Context (surface);
        context.scale (zoom, zoom);
        page.render (context);

        // Writing the surface to the image
        Gdk.Pixbuf pixbuf = Gdk.pixbuf_get_from_surface (surface, 0, 0, width, height);
        image.set_from_pixbuf (pixbuf);
        this.show_all ();
        lastRenderedPage = page;
    }

    private void render_last_page () {
        if (lastRenderedPage != null) {
            render_page.begin (lastRenderedPage);
        }
    }

    public bool handle_key_press_event (Gdk.EventKey k) {
        print ("+");
        if (k.keyval == Gdk.Key.Control_L) {
            busyZooming = true;
        }
        return false;
    }

    public bool handle_key_release_event (Gdk.EventKey k) {
        print ("-");
        if (k.keyval == Gdk.Key.Control_L) {
            busyZooming = false;
        }
        return false;
    }

    public bool handle_scroll_event (Gdk.EventScroll e) {
        print (".");
        if ((e.direction == Gdk.ScrollDirection.DOWN) && (busyZooming == true)) {
            zoom -= 0.1;
            render_last_page ();
        } else if ((e.direction == Gdk.ScrollDirection.UP) && (busyZooming == true)) {
            zoom += 0.1;
            render_last_page ();
        } else if ((e.direction == Gdk.ScrollDirection.SMOOTH) && (busyZooming == true)) {
            double x_d;
            double y_d;
            e.get_scroll_deltas (out x_d, out y_d);
            double new_zoom = zoom + (0.1 * y_d);
            if (new_zoom > 0) {
                zoom = new_zoom;
            }
            render_last_page ();
        }
        return false;
    }
}