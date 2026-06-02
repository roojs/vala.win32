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
vapidir = meson.project_source_root() / 'vapi'
metadata_root = meson.project_source_root() / 'metadata'
filter_file = metadata_root / 'filters' / 'gui.filter'

generate_sources = files(
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

# Linux smoke test: compile example to C only (no Windows link).
custom_target(
  'compile-check',
  input: files('examples/hello-window.vala'),
  output: 'hello-window.vala.c',
  command: [
    valac,
    '--vapidir', vapidir,
    '--pkg', 'win32-ui',
    '--pkg', 'win32-ui-native',
    '--profile=posix',
    '-C',
    '-d', '@OUTDIR@',
    '@INPUT@',
  ],
  build_by_default: not meson.is_cross_build(),
)

# Cross build (meson setup build-win --cross-file cross/mingw-w64.ini).
if meson.is_cross_build()
  executable(
    'hello-window',
    files('examples/hello-window.vala'),
    vala_args: [
      '--vapidir', vapidir,
      '--pkg', 'win32-ui',
    '--pkg', 'win32-ui-native',
      '--profile=posix',
      '-X', '-mwindows',
      '-X', '-luser32',
      '-X', '-lgdi32',
    ],
    install: false,
  )
endif

generated_vapi = vapidir / 'win32-ui.generated.vapi'
check_regen = find_program('scripts/check-regen.sh')

run_target(
  'regen',
  command: [
    generate_binding,
    '--metadata', metadata_root / 'win32json',
    '--filter', filter_file,
    '--out', vapidir,
    '--basename', 'win32-ui.generated.vapi',
    '--debug-critical',
  ],
)

run_target(
  'check-regen',
  command: [
    check_regen,
    generate_binding,
    metadata_root / 'win32json',
    filter_file,
    meson.current_build_dir(),
    generated_vapi,
  ],
)
