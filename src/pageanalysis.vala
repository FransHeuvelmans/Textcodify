using Gee;
using Poppler;


public class PageAnalysis {
    // Extra tools around Poppler pages

    public struct CenterPoint {
        double x;
        double y;
    }

    public struct TextAnnotation {
        string annotation;
        string full_line;  // The larger context to help make it unique
    }

    private Page current_page;
    private Rectangle[] current_textboxes;

    public PageAnalysis (Page p) {
        this.current_page = p;
        this.current_page.get_text_layout (out this.current_textboxes);
    }

    // current_textboxes need manual freeing but this is being done
    // by some other process
    // ~PageAnalysis () {
    // g_free (current_textboxes);
    // }

    /**
     * Get wordlevel-text for a location on a Poppler page
     */
    public TextAnnotation get_closest_text (double x, double y) {
        // Go over all boxes and collect the ones which box in the point
        var enboxing = new ArrayList<Rectangle ? > ();
        foreach (Rectangle r in current_textboxes) {
            if (r.x1 < x < r.x2) {
                if (r.y1 < y < r.y2) {
                    enboxing.add (r);
                }
            }
        }

        string txt;
        string txtline;
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
            /* Could be a rectangle around a letter box at
             * this point. Important if we want to add box
             * information later
             */
            txt = this.current_page.get_selected_text (
                SelectionStyle.WORD,
                dr
            );
            txtline = this.current_page.get_selected_text (
                SelectionStyle.LINE,
                dr
            );
            return TextAnnotation () {
                annotation = txt,
                full_line = txtline
            };
        } else {
            // Not clicked in a box -> fall back on closest
            return this.text_closest_centerpoint (x, y);
        }
    }

    /**
     * Find the textbox closest to a given point by finding the closest
     * box centerpoints
     */
    private TextAnnotation text_closest_centerpoint (double x, double y) {
        var center_points = new ArrayList<CenterPoint ? > ();
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
        var txt = this.current_page.get_selected_text (
            SelectionStyle.WORD, dr
        );
        var txtline = this.current_page.get_selected_text (
                SelectionStyle.LINE,
                dr
            );
        return TextAnnotation () {
            annotation = txt,
            full_line = txtline
        };
    }

    /**
     * Need to work around the fact that we only get a string from poppler
     * and not a slice location in the text.
     * Current error-prone solution is to add the full line as extra info
     * (this does mean that if Poppler here sees it as a separate line, it also
     * preferably is a separate line in the final full-page-text-string used)
     */
}