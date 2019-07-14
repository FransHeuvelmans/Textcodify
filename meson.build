project('textcodify', 'vala', 'c')

dependencies = [
    dependency('glib-2.0'),
    dependency('gobject-2.0'),
    dependency('gtk+-3.0'),
    dependency('poppler-glib'),
]

sources = files(
    'src/app.vala',
    'src/header.vala',
    'src/viewwindow.vala',
    'src/docview.vala',
    'src/controller.vala' 
)

executable(meson.project_name(), sources, dependencies: dependencies, install: true)

install_data(
    join_paths('data', meson.project_name() + '.desktop'),
    install_dir: join_paths(get_option('datadir'), 'applications')
)

install_data(
    join_paths('data', meson.project_name() + '.appdata.xml'),
    install_dir: join_paths(get_option('datadir'), 'metainfo')
)
