project(
  'vala.win32',
  ['vala', 'c'],
  version: '0.1.0',
  meson_version: '>= 1.0.0',
  default_options: ['buildtype=debugoptimized'],
)

gee = dependency('gee-0.8')
json_glib = dependency('json-glib-1.0')

valac = find_program('valac')
project_root = meson.project_source_root()
vapidir = project_root / 'vapi'
metadata_root = project_root / 'metadata'
filter_file = metadata_root / 'filters' / 'gui.filter'
api_list_file = metadata_root / 'win32json-api.files'

example_pkgs = [
  'win32-ui-windowsandmessaging',
  'win32-system-stub',
  'win32-foundation-stub',
  'win32-graphics-gdi',
]

generated_root = project_root / 'generated'
control_strings_vala = generated_root / 'win32-ui-control-strings.vala'
wide_strings_vala = generated_root / 'win32-wide-strings.vala'
widgets_vala = generated_root / 'win32-widgets.vala'
errors_vala = generated_root / 'win32-errors.vala'

example_pkg_dialogs = 'win32-ui-controls-dialogs'
example_pkg_gdi = 'win32-graphics-gdi'

# Track A — raw Win32 (--profile=posix, no GLib)
# [name, source, companion .vala sources, extra --pkg, extra -l libs]
posix_example_apps = [
  ['hello-window', 'examples/hello-window.vala', [wide_strings_vala], [], []],
  ['button-demo', 'examples/button-demo.vala', [control_strings_vala, wide_strings_vala], [], []],
  ['dialog-demo', 'examples/dialog-demo.vala', [wide_strings_vala], [], []],
  [
    'common-dialog-demo',
    'examples/common-dialog-demo.vala',
    [control_strings_vala, wide_strings_vala],
    [example_pkg_dialogs],
    ['comdlg32'],
  ],
  ['menu-demo', 'examples/menu-demo.vala', [wide_strings_vala], [], []],
  ['error-demo', 'examples/error-demo.vala', [errors_vala, wide_strings_vala], [], []],
]

generate_sources = files(
  'src/Generate/ApiFileList.vala',
  'src/Generate/ApplicationInterface.vala',
  'src/Generate/NameMapper.vala',
  'src/Generate/SymbolFilter.vala',
  'src/Generate/VapiEmitter.vala',
  'src/Generate/ErrorEmitter.vala',
  'src/Generate/WidgetCodegen.vala',
  'src/Generate/WidgetEmitter.vala',
  'src/Generate/WideStringsEmitter.vala',
  'src/Generate/Parser/WidgetBehaviorProfileSpec.vala',
  'src/Generate/Parser/WidgetConventionsFile.vala',
  'src/Generate/Parser/ApiFileEntry.vala',
  'src/Generate/Parser/ApiFile.vala',
  'src/Generate/Parser/Base.vala',
  'src/Generate/Parser/Constant.vala',
  'src/Generate/Parser/EnumValue.vala',
  'src/Generate/Parser/Field.vala',
  'src/Generate/Parser/Function.vala',
  'src/Generate/Parser/MetadataType.vala',
  'src/Generate/Parser/Parameter.vala',
  'src/Generate/Parser/TypeRef.vala',
  'tools/generate-binding.vala',
)

generate_binding = executable(
  'generate-binding',
  generate_sources,
  dependencies: [gee, json_glib],
  install: false,
)

regen_base_cmd = [
  generate_binding,
  '--metadata', metadata_root / 'win32json',
  '--filter', filter_file,
  '--api-list', api_list_file,
  '--out', vapidir,
  '--debug-critical',
]

regen_vapi = custom_target(
  'regen-vapi',
  output: 'regen.stamp',
  command: regen_base_cmd + ['&&', 'touch', '@OUTPUT@'],
  build_by_default: true,
)

mingw_cc = find_program('x86_64-w64-mingw32-gcc', required: false)
mingw64_lib = project_root / 'mingw-libs' / 'mingw64'
mingw_pc_dir = mingw64_lib / 'lib' / 'pkgconfig'
gobject_spike_pc = mingw_pc_dir / 'glib-2.0.pc'
have_mingw_glib = run_command('test', '-f', gobject_spike_pc, check: false).returncode() == 0

glib_pc_env = ['env', 'PKG_CONFIG_LIBDIR=' + mingw_pc_dir]
glib_cflags = []
glib_link = [
  '-L' + (mingw64_lib / 'lib'),
  '-lgobject-2.0',
  '-lglib-2.0',
  '-liconv',
]
if have_mingw_glib
  glib_cflags = run_command(
    glib_pc_env,
    'pkg-config',
    '--cflags',
    'glib-2.0',
    'gobject-2.0',
    check: true,
  ).stdout().strip().split()
endif

foreach app : posix_example_apps
  app_name = app[0]
  app_source = app[1]
  app_extra_sources = app[2]
  app_extra_pkgs = app[3]
  app_extra_libs = app[4]
  app_vala_args = ['--vapidir', vapidir, '--profile=posix']
  foreach pkg : example_pkgs
    app_vala_args += ['--pkg', pkg]
  endforeach
  foreach pkg : app_extra_pkgs
    app_vala_args += ['--pkg', pkg]
  endforeach
  app_link_libs = ['-luser32', '-lgdi32', '-lcomctl32']
  foreach lib : app_extra_libs
    app_link_libs += ['-l' + lib]
  endforeach
  app_vala_link = ['-X', '-mwindows']
  foreach lib : app_link_libs
    app_vala_link += ['-X', lib]
  endforeach
  app_companion_sources = app_extra_sources
  if host_machine.system() == 'windows'
    win_inputs = [files(app_source)]
    foreach src : app_companion_sources
      win_inputs += src
    endforeach
    executable(
      app_name,
      win_inputs,
      vala_args: app_vala_args + app_vala_link,
      link_args: ['-mwindows'] + app_link_libs,
      depends: regen_vapi,
      install: false,
    )
  elif mingw_cc.found()
    app_build_dir = 'track-a-' + app_name
    companion_c_files = []
    app_vala_inputs = [files(app_source)]
    foreach src : app_companion_sources
      app_vala_inputs += src
      parts = src.split('/')
      vala_name = parts[-1]
      companion_c_files += app_build_dir + '/' + vala_name.substring(0, -5) + '.c'
    endforeach
    custom_target(
      app_name,
      input: app_vala_inputs,
      output: app_name + '.exe',
      command: [
        'mkdir', '-p', app_build_dir,
        '&&',
        valac,
        app_vala_args,
        '-C',
        '-d', app_build_dir,
        '@INPUT@',
        '&&',
        mingw_cc,
        '-mwindows',
        '-o', '@OUTPUT@',
        app_build_dir + '/' + app_name + '.c',
        companion_c_files,
      ] + app_link_libs,
      depends: regen_vapi,
      build_by_default: true,
    )
  else
    warning(app_name + '.exe skipped: x86_64-w64-mingw32-gcc not found')
  endif
endforeach

# Track B — ergonomic widgets (--profile=gobject + MinGW GLib)
# [name, source, extra companion .vala, extra --pkg, extra -l libs]
ergonomic_widget_companion = [control_strings_vala, wide_strings_vala, widgets_vala]

ergonomic_apps = [
  [
    'ergonomic-button-demo',
    'examples/ergonomic-button-demo.vala',
    ergonomic_widget_companion,
    [],
    [],
  ],
  [
    'ergonomic-dialog-demo',
    'examples/ergonomic-dialog-demo.vala',
    ergonomic_widget_companion,
    [],
    [],
  ],
  [
    'ergonomic-common-dialog-demo',
    'examples/ergonomic-common-dialog-demo.vala',
    ergonomic_widget_companion,
    [],
    ['comdlg32'],
  ],
  [
    'ergonomic-menu-demo',
    'examples/ergonomic-menu-demo.vala',
    ergonomic_widget_companion,
    [],
    [],
  ],
  [
    'ergonomic-error-demo',
    'examples/ergonomic-error-demo.vala',
    [errors_vala, wide_strings_vala],
    [],
    [],
  ],
]

if mingw_cc.found() and have_mingw_glib
  track_b_pkgs = example_pkgs + ['win32-ui-controls', example_pkg_dialogs]
  ergo_vala_args_base = ['--vapidir', vapidir, '--profile=gobject']
  foreach pkg : track_b_pkgs
    ergo_vala_args_base += ['--pkg', pkg]
  endforeach
  ergo_link_libs = ['-luser32', '-lgdi32', '-lcomctl32']
  foreach app : ergonomic_apps
    app_name = app[0]
    app_source = app[1]
    app_companion = app[2]
    app_extra_pkgs = app[3]
    app_extra_libs = app[4]
    ergo_vala_args = []
    foreach a : ergo_vala_args_base
      ergo_vala_args += a
    endforeach
    foreach pkg : app_extra_pkgs
      ergo_vala_args += ['--pkg', pkg]
    endforeach
    ergo_build_dir = 'track-b-' + app_name
    ergo_companion_c = []
    ergo_vala_inputs = [files(app_source)]
    foreach src : app_companion
      ergo_vala_inputs += src
      parts = src.split('/')
      vala_name = parts[-1]
      ergo_companion_c += ergo_build_dir + '/' + vala_name.substring(0, -5) + '.c'
    endforeach
    app_link = glib_link + ergo_link_libs
    foreach lib : app_extra_libs
      app_link += ['-l' + lib]
    endforeach
    custom_target(
      app_name,
      input: ergo_vala_inputs,
      output: app_name + '.exe',
      command: [
        'mkdir', '-p', ergo_build_dir,
        '&&',
        valac,
        ergo_vala_args,
        '-C',
        '-d', ergo_build_dir,
        '@INPUT@',
        '&&',
        mingw_cc,
        '-mwindows',
        glib_cflags,
        '-o', '@OUTPUT@',
        ergo_build_dir + '/' + app_name + '.c',
        ergo_companion_c,
      ] + app_link + [
        '&&',
        'sh',
        '-c',
        'cp "' + mingw64_lib / 'bin' + '"/*.dll "$1"',
        '--',
        '.',
      ],
      depends: regen_vapi,
      build_by_default: true,
    )
  endforeach
else
  if mingw_cc.found() and not have_mingw_glib
    warning(
      'Track B ergonomic demos skipped: run ./scripts/setup-mingw-libs.sh',
    )
  elif not mingw_cc.found()
    warning('Track B ergonomic demos skipped: x86_64-w64-mingw32-gcc not found')
  endif
endif

check_regen = find_program('scripts/check-regen.sh')

run_target('regen', command: regen_base_cmd)

run_target(
  'regen-monolith',
  command: regen_base_cmd + ['--monolith', '--basename', 'win32-ui.generated.vapi'],
)

run_target(
  'check-regen',
  command: [
    check_regen,
    generate_binding,
    metadata_root / 'win32json',
    filter_file,
    meson.current_build_dir() / 'vapi-check',
    api_list_file,
    vapidir,
  ],
)
