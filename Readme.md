# Textcodify

This a program used for creating NLP-style annotations for PDF files.

At the moment the codebase is in a messy state with a lot of global state and mutations.
It can't export yet, all annotations are stored in an SQLite database. 
It is more of an experiment with Vala (+ Poppler/SQLite) than a full program.
Furthermore, PDFs are not the right type of files to do text analysis on.
There is only limited information that can be extracted.
But if you have to use PDFs and are in need of a free tool it might be useful.

## Alternatives

There are better tools out there for both pdf and non-pdf annotation tasks:

* [Pawls][11] (PDF annotation online by AllenAI)
* [Prodigy][2] (Payed but supports the great Spacy.io) 
* [Doccano][1]
* [Tawseem][3]
* [Brat][4]
* [Universal Data Tool][8]
* [Label studio][7]
* [Markup][12] (See [their website][13] for more info)
* [Tagtog][5] (Payed)

[And][10] [more][9]

## Development
Builds are done using [Meson's Vala support][6].

Setup a builddir using `meson setup builddir/` then compilation
is done inside the builddir using `ninja`.

Checkout `meson.build` for latest system dependencies.

[1]: https://github.com/doccano/doccano
[2]: https://prodi.gy/
[3]: https://github.com/salsowelim/tawseem
[4]: http://brat.nlplab.org/
[5]: https://www.tagtog.net/
[6]: https://mesonbuild.com/Vala.html
[7]: https://github.com/heartexlabs/label-studio
[8]: https://github.com/UniversalDataTool/universal-data-tool
[9]: https://github.com/heartexlabs/awesome-data-labeling#text
[10]: https://github.com/jsbroks/awesome-dataset-tools#text
[11]: https://github.com/allenai/pawls
[12]: https://github.com/samueldobbie/markup
[13]: https://www.getmarkup.com/