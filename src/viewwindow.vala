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

    /**
     * Convert the click location in the viewwindow to where it
     * would be on the pdf-file
     */
    public TextcodeApp.MouseLoc convert_click_loc (double x, double y) {
        // Widget and image sizes
        Gdk.Pixbuf pb = this.image.get_pixbuf ();
        int wid_width = this.eventBox.get_allocated_width ();
        int wid_height = this.eventBox.get_allocated_height ();

        // calculate where the mouse should be on the image
        // (widget -> image loc)
        int diff;
        double x_diff;
        double x_out;
        if (wid_width > pb.width) {
            diff = wid_width - pb.width;
            x_diff = (double) diff / 2;
            x_out = x - x_diff;
            if (x_out < 0) {
                x_out = 0;
            }
        } else {
            x_out = x;
        }
        double y_diff;
        double y_out;
        if (wid_height > pb.height) {
            diff = wid_height - pb.height;
            y_diff = (double) (diff / 2);
            y_out = y - y_diff;
            if (y_out < 0) {
                y_out = 0;
            }
        } else {
            y_out = y;
        }

        // calculate where it should be on the page
        // (image loc -> original page loc)
        x_out = x_out / this.zoom;
        y_out = y_out / this.zoom;
        var areturn = TextcodeApp.MouseLoc () {
            x = x_out,
            y = y_out
        };
        return areturn;
    }
}