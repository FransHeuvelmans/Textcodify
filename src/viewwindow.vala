using Cairo;
using Gtk;

public class ViewWindow : ScrolledWindow {

// To store the document and the current page
    private Image image;
    private EventBox eventBox;
    private double zoom = 1;
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
        this.show_all ();
    }

    public async void render_page (Poppler.Page page) {
        // Getting the right size
        double page_width;
        double page_height;
        page.get_size (out page_width, out page_height);
        int width = (int) (zoom * page_width);
        int height = (int) (zoom * page_height);

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

    public void set_active_zooming (bool zoom) {
        if (lastRenderedPage != null) {
            busyZooming = zoom;
        }
    }

    public void zoom_down () {
        if (busyZooming) {
            zoom -= 0.1;
            render_last_page ();
        }
    }

    public void zoom_up () {
        if (busyZooming) {
            zoom += 0.1;
            render_last_page ();
        }
    }

    public void adjust_location (double x_d, double y_d) {
        Adjustment y = this.get_vadjustment ();
        double new_y = y.value + y_d;
        if (y.lower < new_y < y.upper) {
            y.value = new_y;
        }
        this.set_vadjustment (y);

        Adjustment x = this.get_hadjustment ();
        double new_x = x.value + x_d;
        if (x.lower < new_x < x.upper) {
            x.value = new_x;
        }
        this.set_hadjustment (x);
    }

    /**
     * For smooth scrolling. Works only in y-axis atm
     */
    public void smooth_zoom (double y_d) {
        if (busyZooming) {
            double new_zoom = zoom + (0.1 * y_d);
            if (new_zoom > 0.1) {
                zoom = new_zoom;
            }
            render_last_page ();
        }
    }

    private void render_last_page () {
        if (lastRenderedPage != null) {
            render_page.begin (lastRenderedPage);
        }
    }
}