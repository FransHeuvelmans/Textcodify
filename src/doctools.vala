using Gee;
using Poppler;


public class DocTools {

    public struct CenterPoint {
        double x;
        double y;
    }

    private Page current_page;
    private Rectangle[] current_textboxes;

    public DocTools (Page p) {
        print ("Analyzing page\n");
        this.current_page = p;
        this.current_page.get_text_layout (out this.current_textboxes);
    }

    public ~DocTools() {
        g_free (current_textboxes);
    }

    public void print_textboxes () {
        foreach (Rectangle r in current_textboxes) {
            print (@"Rect - x1: $(r.x1) y1: $(r.y1) x2: $(r.x2) y2: $(r.y2)\n");
            string txt = this.current_page.get_selected_text (
                SelectionStyle.WORD, r
            );
            print (@"txt - $txt \n");
        }
    }

    public void print_closest_text (double x, double y) {
        // Go over all boxes and collect the ones which box in the point
        var enboxing = new ArrayList<Rectangle?> ();
        foreach (Rectangle r in current_textboxes) {
            if (r.x1 < x < r.x2) {
                if (r.y1 < y < r.y2) {
                    enboxing.add (r);
                }
            }
        }

        string txt;
        if (enboxing.size > 0) {
            // if list is non-empty, use the smallest box
            int idx_smallest = -1;
            double size_smallest = double.MAX;
            Rectangle r;
            double size;
            for (int i = 0; i < enboxing.size; i++) {
                r = enboxing[i];
                size = (r.x2 - r.x1) * (r.y2 - r.y1);
                if (size < size_smallest) {
                    idx_smallest = i;
                    size_smallest = size;
                }
            }
            Rectangle dr = enboxing[idx_smallest];
            print (@"debug smallest Rect - x1: $(dr.x1) y1: $(dr.y1) x2: $(dr.x2) y2: $(dr.y2)\n");
            txt = this.current_page.get_selected_text (
                SelectionStyle.WORD,
                dr
            );
        } else {
            // if list is empty, get create a list of "middle-points" of boxes
            // get the box with the middle-point closest to the point
            txt = this.text_closest_centerpoint (x, y);
        }
        print (@"txt - $txt \n");
    }

    private string text_closest_centerpoint (double x, double y) {
        var center_points = new ArrayList<CenterPoint?> ();
        foreach (Rectangle r in current_textboxes) {
            double center_x = r.x1 + ((r.x2 - r.x1) / 2);
            double center_y = r.y1 + ((r.y2 - r.y1) / 2);
            var cp = CenterPoint () {
                x = center_x,
                y = center_y
            };
            center_points.add (cp);
        }
        int idx_closest = -1;
        double distance_closest = double.MAX;
        CenterPoint cp;
        double dist;
        for (int i = 0; i < center_points.size; i++) {
            cp = center_points[i];
            dist = Math.sqrt (Math.pow (x - cp.x, 2) + Math.pow (y - cp.y, 2));
            if (dist < distance_closest) {
                idx_closest = i;
                distance_closest = dist;
            }
        }
        Rectangle dr = current_textboxes[idx_closest];
        print (@"debug closest Rect - x1: $(dr.x1) y1: $(dr.y1) x2: $(dr.x2) y2: $(dr.y2)\n");
        return this.current_page.get_selected_text (
            SelectionStyle.WORD, dr
        );
    }
}