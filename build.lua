return {
  name = 'Kyma',
  developer = '0xS4cha',
  version = '0.1',
  love = '11.5',
  output = 'dist',
  identifier = 'com.kyma.game',
  platforms = {'windows', 'macos', 'linux'},
  ignore = {
    'dist', 'build', 'tests', 'docs', 'love-build', 'lib',
    'Makefile', '.env', '.env.example', '.luarc.json', '.github',
    'build.lua', 'CODE_OF_CONDUCT.md', 'appimagetool.AppImage', 'kyma'
  }
}
