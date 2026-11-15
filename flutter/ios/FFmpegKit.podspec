# Converter only. Playback remains AVPlayerViewController.
Pod::Spec.new do |s|
  s.name = 'BrenTVFFmpeg'
  s.version = '8.1.2'
  s.summary = 'Minimal FFmpegKit libraries for local MP4 conversion'
  s.homepage = 'https://github.com/sk3llo/ffmpeg_kit_flutter'
  s.author = 'FFmpegKit contributors'
  s.license = { :type => 'LGPL-3.0', :file => 'ffmpegkit.framework/LICENSE' }
  s.source = {
    :http => 'https://github.com/sk3llo/ffmpeg_kit_flutter/releases/download/8.1.2-min/ffmpeg-kit-ios-min-8.1.2.zip',
    :sha256 => 'de338cc8b98f32c6e8e35a60c913247f3f60fbc38634edcf7923259240803b9d'
  }
  s.ios.deployment_target = '14.0'
  s.vendored_frameworks = '*.framework'
  s.frameworks = 'AudioToolbox', 'AVFoundation', 'CoreMedia', 'VideoToolbox'
  s.libraries = 'z', 'bz2', 'c++', 'iconv'
end
