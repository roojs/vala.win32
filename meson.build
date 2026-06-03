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
]

generated_root = project_root / 'generated'
control_strings_vala = generated_root / 'win32-ui-control-strings.vala'
wide_strings_vala = generated_root / 'win32-wide-strings.vala'
widgets_vala = generated_root / 'win32-widgets.vala'

example_apps = [
  ['hello-window', 'examples/hello-window.vala', example_pkgs, [wide_strings_vala]],
  [
    'button-demo',
    'examples/button-demo.vala',
    example_pkgs,
    [control_strings_vala, wide_strings_vala],
  ],
  [
    'ergonomic-button-demo',
    'examples/ergonomic-button-demo.vala',
    example_pkgs,
    [control_strings_vala, wide_strings_vala, widgets_vala],
  ],
]

generate_sources = files(
  'src/Generate/ApiFileList.vala',
  'src/Generate/ApplicationInterface.vala',
  'src/Generate/NameMapper.vala',
  'src/Generate/SymbolFilter.vala',
  'src/Generate/VapiEmitter.vala',
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

foreach app : example_apps
  app_name = app[0]
  app_source = app[1]
  app_pkgs = app[2]
  app_extra_sources = app[3]
  app_vala_args = ['--vapidir', vapidir]
  foreach pkg : app_pkgs
    app_vala_args += ['--pkg', pkg]
  endforeach
  app_vala_args += '--profile=posix'
  app_inputs = files(app_source)
  app_companion_sources = app_extra_sources
  if host_machine.system() == 'windows'
    win_inputs = [files(app_source)]
    foreach src : app_companion_sources
      win_inputs += src
    endforeach
    executable(
      app_name,
      win_inputs,
      vala_args: app_vala_args + ['-X', '-mwindows', '-X', '-luser32', '-X', '-lgdi32', '-X', '-lcomctl32'],
      link_args: ['-mwindows', '-luser32', '-lgdi32', '-lcomctl32'],
      depends: regen_vapi,
      install: false,
    )
  elif mingw_cc.found()
    companion_c_files = []
    companion_vala_cmd = []
    foreach src : app_companion_sources
      companion_vala_cmd += src
      parts = src.split('/')
      vala_name = parts[-1]
      companion_c_files += '@OUTDIR@/' + vala_name.substring(0, -5) + '.c'
    endforeach
    custom_target(
      app_name,
      input: files(app_source),
      output: app_name + '.exe',
      command: [
        valac,
        app_vala_args,
        '-C',
        '-d', '@OUTDIR@',
        '@INPUT@',
        companion_vala_cmd,
        '&&',
        mingw_cc,
        '-mwindows',
        '-o', '@OUTPUT@',
        '@OUTDIR@/' + app_name + '.c',
        companion_c_files,
        '-luser32',
        '-lgdi32',
        '-lcomctl32',
      ],
      depends: regen_vapi,
      build_by_default: true,
    )
  else
    warning(app_name + '.exe skipped: x86_64-w64-mingw32-gcc not found')
  endif
endforeach

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
