project(
  'vala.win32',
  ['vala', 'c'],
  version: '0.1.0',
  meson_version: '>= 1.0.0',
  default_options: ['buildtype=debugoptimized'],
)

# Repetitive GCC noise from Vala-generated Win32 C (not actionable for app code).
vala_win32_c_quiet = []
if host_machine.system() == 'windows'
  vala_win32_c_quiet = [
    '-Wno-discarded-qualifiers',
    '-Wno-incompatible-pointer-types',
    '-Wno-implicit-function-declaration',
  ]
  add_project_arguments(vala_win32_c_quiet, language: 'c')
endif

vala_win32_quiet_x = []
foreach flag : vala_win32_c_quiet
  vala_win32_quiet_x += ['-X', flag]
endforeach

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
webview2_host_glue_vala = generated_root / 'win32-ui-webview2-host-glue.vala'

example_pkg_dialogs = 'win32-ui-controls-dialogs'
example_pkg_gdi = 'win32-graphics-gdi'

# Track A — raw Win32 (--profile=posix, no GLib)
# [name, source, companion .vala sources, extra --pkg, extra -l libs]
posix_example_apps = [
  ['native-hello-window', 'examples/native/hello-window.vala', [wide_strings_vala], [], []],
  ['native-button-demo', 'examples/native/button-demo.vala', [control_strings_vala, wide_strings_vala], [], []],
  ['native-dialog-demo', 'examples/native/dialog-demo.vala', [wide_strings_vala], [], []],
  [
    'native-common-dialog-demo',
    'examples/native/common-dialog-demo.vala',
    [control_strings_vala, wide_strings_vala],
    [example_pkg_dialogs],
    ['comdlg32'],
  ],
  ['native-menu-demo', 'examples/native/menu-demo.vala', [wide_strings_vala], [], []],
  ['native-error-demo', 'examples/native/error-demo.vala', [errors_vala, wide_strings_vala], [], []],
]

generate_sources = files(
  'src/Generate/ApiFileList.vala',
  'src/Generate/ApplicationInterface.vala',
  'src/Generate/NameMapper.vala',
  'src/Generate/SymbolFilter.vala',
  'src/Generate/VapiEmitter.vala',
  'src/Generate/CoverageReport.vala',
  'src/Generate/ErrorEmitter.vala',
  'src/Generate/WidgetCodegen.vala',
  'src/Generate/WidgetEmitter.vala',
  'src/Generate/WebView2GlueEmitter.vala',
  'src/Generate/WideStringsEmitter.vala',
  'src/Generate/Parser/ErgoNativeMapEntry.vala',
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

generate_webview2_json = executable(
  'generate-webview2-json',
  files('tools/generate-webview2-json.vala'),
  dependencies: [json_glib],
  install: false,
)

regen_base_cmd = [
  generate_binding,
  '--metadata', metadata_root / 'win32json',
  '--filter', filter_file,
  '--api-list', api_list_file,
  '--out', vapidir,
]

regen_vapi = custom_target(
  'regen-vapi',
  output: 'regen.stamp',
  command: regen_base_cmd + ['&&', 'touch', '@OUTPUT@'],
  build_by_default: get_option('regen_on_build'),
)

# When regen_on_build is false, use committed vapi/ + generated/*.vala (build-win on Samba).
regen_dep = regen_vapi
if not get_option('regen_on_build')
  regen_dep = []
endif

mingw_cc = find_program('x86_64-w64-mingw32-gcc', required: false)
mingw_windres = find_program('x86_64-w64-mingw32-windres', required: false)
widgets_demo_rc = project_root / 'examples' / 'widgets-demo.rc'
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

if get_option('build_posix_examples')
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
  app_vala_link = ['-X', '-mwindows'] + vala_win32_quiet_x
  foreach lib : app_link_libs
    app_vala_link += ['-X', lib]
  endforeach
  app_companion_sources = app_extra_sources
  if host_machine.system() == 'windows'
    win_inputs = [files(app_source)]
    if get_option('regen_on_build')
      win_inputs += regen_vapi
    endif
    foreach src : app_companion_sources
      win_inputs += src
    endforeach
    executable(
      app_name,
      win_inputs,
      vala_args: app_vala_args + app_vala_link,
      link_args: ['-mwindows'] + app_link_libs,
      install: false,
    )
  elif mingw_cc.found()
    app_build_dir = 'track-a-' + app_name
    app_source_parts = app_source.split('/')
    app_vala_basename = app_source_parts[-1].substring(0, -5)
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
      ] + vala_win32_c_quiet + [
        '-mwindows',
        '-o', '@OUTPUT@',
        app_build_dir + '/' + app_vala_basename + '.c',
        companion_c_files,
      ] + app_link_libs,
      depends: regen_dep,
      build_by_default: true,
    )
  else
    warning(app_name + '.exe skipped: x86_64-w64-mingw32-gcc not found')
  endif
endforeach
endif

# Track B — ergonomic widgets (--profile=gobject + MinGW GLib)
# [name, source, extra companion .vala, extra --pkg, extra -l libs]
ergonomic_widget_companion = [control_strings_vala, wide_strings_vala, widgets_vala]

ergonomic_apps = [
  [
    'hello-window',
    'examples/hello-window.vala',
    ergonomic_widget_companion,
    [],
    [],
  ],
  [
    'button-demo',
    'examples/button-demo.vala',
    ergonomic_widget_companion,
    [],
    [],
  ],
  [
    'widgets-demo',
    'examples/widgets-demo.vala',
    ergonomic_widget_companion,
    [],
    [],
  ],
  [
    'dialog-demo',
    'examples/dialog-demo.vala',
    ergonomic_widget_companion,
    [],
    [],
  ],
  [
    'common-dialog-demo',
    'examples/common-dialog-demo.vala',
    ergonomic_widget_companion,
    [],
    ['comdlg32'],
  ],
  [
    'menu-demo',
    'examples/menu-demo.vala',
    ergonomic_widget_companion,
    [],
    [],
  ],
  [
    'error-demo',
    'examples/error-demo.vala',
    [errors_vala, wide_strings_vala],
    [],
    [],
  ],
]

if get_option('build_ergonomic_examples') and mingw_cc.found() and have_mingw_glib
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
    ergo_cc_extra = []
    ergo_link_objs = []
    if app_name == 'widgets-demo' and mingw_windres.found()
      ergo_link_objs += [ergo_build_dir + '/manifest.o']
    endif
    ergo_link_cmd = [
      mingw_cc,
    ] + vala_win32_c_quiet + [
      '-mwindows',
    ] + ergo_cc_extra + glib_cflags + [
      '-o', '@OUTPUT@',
      ergo_build_dir + '/' + app_name + '.c',
      ergo_companion_c,
    ] + ergo_link_objs + app_link
    ergo_build_cmd = [
      'mkdir', '-p', ergo_build_dir,
      '&&',
      valac,
      ergo_vala_args,
      '-C',
      '-d', ergo_build_dir,
      '@INPUT@',
    ]
    if app_name == 'widgets-demo' and mingw_windres.found()
      ergo_build_cmd += [
        '&&',
        mingw_windres,
        '-I', project_root / 'examples',
        '-i', widgets_demo_rc,
        '-o', ergo_build_dir + '/manifest.o',
      ]
    endif
    ergo_build_cmd += ['&&'] + ergo_link_cmd
    custom_target(
      app_name,
      input: ergo_vala_inputs,
      output: app_name + '.exe',
      command: ergo_build_cmd + [
        '&&',
        'sh',
        '-c',
        'cp "' + mingw64_lib / 'bin' + '"/*.dll "$1"',
        '--',
        '.',
      ],
      depends: regen_dep,
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

# Phase 7 — WebView2 host (Windows host only; requires ./scripts/vendor-webview2-sdk.sh)
# JSON/vapi regen still works on Linux; see scripts/regen-webview2-*.sh
webview2_sdk = project_root / 'build/vendor/webview2'
webview2_header = webview2_sdk / 'include' / 'WebView2.h'
webview2_loader_x64 = webview2_sdk / 'x64' / 'WebView2Loader.dll'
have_webview2_sdk = run_command('test', '-f', webview2_header, check: false).returncode() == 0
vendor_webview2 = find_program('scripts/vendor-webview2-sdk.sh')
webview2_loader_c = project_root / 'src' / 'win32-ui-webview2-loader.c'
webview2_com_glue_c = project_root / 'src' / 'win32-ui-webview2-com-glue.c'
webview2_host_vala = files('src/win32-ui-webview2-host.vala')
webview2_link_libs = ['-lole32', '-luuid', '-lshell32', '-ladvapi32']

if have_webview2_sdk
  webview2_vala_args = ['--vapidir', vapidir, '--profile=posix', '--pkg', 'win32-ui-webview2']
  foreach pkg : example_pkgs
    webview2_vala_args += ['--pkg', pkg]
  endforeach
  webview2_vala_link = ['-X', '-mwindows'] + vala_win32_quiet_x
  foreach lib : webview2_link_libs
    webview2_vala_link += ['-X', lib]
  endforeach
  webview2_inc = include_directories(
    'build/vendor/webview2/include',
    'src',
  )
endif

if have_webview2_sdk and host_machine.system() == 'windows'
  webview2_sources = [
    files('examples/native/webview2-host-demo.vala'),
    webview2_host_vala,
    webview2_host_glue_vala,
    wide_strings_vala,
    webview2_loader_c,
    webview2_com_glue_c,
  ]
  if get_option('regen_on_build')
    webview2_sources += regen_vapi
  endif
  webview2_host_exe = executable(
    'webview2-host-demo',
    webview2_sources,
    vala_args: webview2_vala_args + webview2_vala_link,
    include_directories: webview2_inc,
    c_args: vala_win32_c_quiet,
    link_args: ['-mwindows'] + webview2_link_libs,
    install: false,
  )
  custom_target(
    'webview2-copy-loader',
    output: 'webview2-loader.stamp',
    command: [
      'cp', webview2_loader_x64, meson.current_build_dir(),
      '&&', 'touch', '@OUTPUT@',
    ],
    depends: webview2_host_exe,
    build_by_default: true,
  )

  webview2_ergo_glib = dependency('glib-2.0', required: false)
  webview2_ergo_gobject = dependency('gobject-2.0', required: false)
  have_webview2_ergo = webview2_ergo_glib.found() and webview2_ergo_gobject.found()
  if have_webview2_ergo
    webview2_ergo_vala_args = ['--vapidir', vapidir, '--profile=gobject', '--pkg', 'win32-ui-webview2']
    foreach pkg : example_pkgs
      webview2_ergo_vala_args += ['--pkg', pkg]
    endforeach
    webview2_ergo_link = ['-X', '-mwindows'] + vala_win32_quiet_x
    foreach lib : webview2_link_libs
      webview2_ergo_link += ['-X', lib]
    endforeach
    webview2_ergo_sources = [
      files('examples/webview2-ergo-demo.vala'),
      files('src/win32-ergo-webview2.vala'),
      webview2_host_vala,
      webview2_host_glue_vala,
      control_strings_vala,
      wide_strings_vala,
      widgets_vala,
      webview2_loader_c,
      webview2_com_glue_c,
    ]
    if get_option('regen_on_build')
      webview2_ergo_sources += regen_vapi
    endif
    webview2_ergo_exe = executable(
      'webview2-ergo-demo',
      webview2_ergo_sources,
      vala_args: webview2_ergo_vala_args + webview2_ergo_link,
      include_directories: webview2_inc,
      c_args: vala_win32_c_quiet,
      dependencies: [webview2_ergo_glib, webview2_ergo_gobject],
      link_args: ['-mwindows'] + webview2_link_libs,
      install: false,
    )
    custom_target(
      'webview2-ergo-copy-loader',
      output: 'webview2-ergo-loader.stamp',
      command: [
        'cp', webview2_loader_x64, meson.current_build_dir(),
        '&&', 'touch', '@OUTPUT@',
      ],
      depends: webview2_ergo_exe,
      build_by_default: true,
    )
  else
    warning('webview2-ergo-demo skipped: install glib2-devel (MSYS2 UCRT64) for Track B WebView')
  endif
elif host_machine.system() == 'windows'
  warning('webview2-host-demo skipped: run ./scripts/vendor-webview2-sdk.sh')
endif

check_regen = find_program('scripts/check-regen.sh')
compile_check = find_program('scripts/compile-check.sh')

run_target('vendor-webview2', command: [vendor_webview2])

webview2_filter = metadata_root / 'filters' / 'webview2.filter'
webview2_api_list = metadata_root / 'webview2-api.files'
regen_webview2_vapi_cmd = [
  generate_binding,
  '--metadata', metadata_root / 'webview2',
  '--filter', webview2_filter,
  '--api-list', webview2_api_list,
  '--out', vapidir,
  '--symbol-prefix', 'Microsoft.Web.WebView2.Win32',
  '--no-basename-in-symbol',
  '--cheader', 'win32-ui-webview2-sdk.h',
  '--vala-namespace', 'Microsoft.Web.WebView2.Win32',
  '--vapi-only',
]

run_target('regen-webview2-vapi', command: regen_webview2_vapi_cmd)

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

run_target(
  'compile-check',
  command: [compile_check],
  depends: regen_dep,
)

run_target(
  'coverage-report',
  command: regen_base_cmd + [
    '--coverage-only',
    '--coverage-report', project_root / 'docs/coverage/6a-coverage-matrix.md',
  ],
)
