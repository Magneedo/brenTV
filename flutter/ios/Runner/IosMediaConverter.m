#import "IosMediaConverter.h"
#import <ffmpegkit/FFmpegKit.h>
#import <ffmpegkit/FFprobeKit.h>
#import <ffmpegkit/FFmpegKitConfig.h>
#import <ffmpegkit/ReturnCode.h>
#import <ffmpegkit/Statistics.h>
#import <UIKit/UIKit.h>
#import <unistd.h>
#import <sys/stat.h>

@implementation IosMediaConverter {
  NSMutableDictionary<NSString *, NSNumber *> *_sessions;
  NSMutableDictionary<NSString *, NSDictionary *> *_progress;
}

- (instancetype)initWithMessenger:(NSObject<FlutterBinaryMessenger> *)messenger {
  self = [super init];
  if (self) {
    _sessions = [NSMutableDictionary dictionary];
    _progress = [NSMutableDictionary dictionary];
    FlutterMethodChannel *channel = [FlutterMethodChannel methodChannelWithName:@"brentv/media_converter" binaryMessenger:messenger];
    __weak typeof(self) weakSelf = self;
    [channel setMethodCallHandler:^(FlutterMethodCall *call, FlutterResult result) {
      [weakSelf handle:call result:result];
    }];
    // No native diagnostics are sent to the user or printed by this bridge.
    [FFmpegKitConfig enableLogCallback:^(Log *log) {}];
  }
  return self;
}

- (NSString *)receiptPath:(NSString *)key {
  NSString *root = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject;
  NSString *name = [key stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.alphanumericCharacterSet];
  return [[root stringByAppendingPathComponent:@"mp4-publications"] stringByAppendingPathComponent:[name stringByAppendingString:@".json"]];
}

- (NSDictionary *)signature:(NSString *)path {
  struct stat value;
  if (lstat(path.fileSystemRepresentation, &value) != 0 || !S_ISREG(value.st_mode)) return nil;
  return @{@"device": @(value.st_dev), @"inode": @(value.st_ino), @"size": @(value.st_size),
           @"modified": @(value.st_mtimespec.tv_sec), @"modifiedNanos": @(value.st_mtimespec.tv_nsec)};
}

- (void)handle:(FlutterMethodCall *)call result:(FlutterResult)result {
  NSDictionary *args = [call.arguments isKindOfClass:[NSDictionary class]] ? call.arguments : @{};
  NSString *key = args[@"id"];
  if (![key isKindOfClass:[NSString class]]) {
    result([FlutterError errorWithCode:@"arguments" message:@"Invalid conversion request" details:nil]); return;
  }
  if ([call.method isEqualToString:@"progress"]) {
    result(_progress[key] ?: @{});
    return;
  }
  if ([call.method isEqualToString:@"cancel"]) {
    NSNumber *session = _sessions[key];
    if (session) [FFmpegKit cancel:session.longValue];
    result(nil);
    return;
  }
  if ([call.method isEqualToString:@"published"]) {
    NSString *destination = args[@"destination"];
    NSData *data = [NSData dataWithContentsOfFile:[self receiptPath:key]];
    NSDictionary *saved = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    NSDictionary *current = [destination isKindOfClass:[NSString class]] ? [self signature:destination] : nil;
    result(@(saved != nil && current != nil && [saved isEqual:current]));
    return;
  }
  if ([call.method isEqualToString:@"discardReceipt"]) {
    [[NSFileManager defaultManager] removeItemAtPath:[self receiptPath:key] error:nil];
    result(nil);
    return;
  }
  if ([call.method isEqualToString:@"publish"]) {
    NSString *source = args[@"source"], *destination = args[@"destination"];
    // Both paths are local in the app container and on the same filesystem.
    // link() publishes atomically and cannot overwrite an existing file.
    NSDictionary *signature = [source isKindOfClass:[NSString class]] ? [self signature:source] : nil;
    NSString *receipt = [self receiptPath:key];
    NSData *data = signature ? [NSJSONSerialization dataWithJSONObject:signature options:0 error:nil] : nil;
    BOOL stored = data && [[NSFileManager defaultManager] createDirectoryAtPath:receipt.stringByDeletingLastPathComponent
      withIntermediateDirectories:YES attributes:nil error:nil] && [data writeToFile:receipt options:NSDataWritingAtomic error:nil];
    // A receipt is durable before publication. It identifies this exact inode,
    // so retry can recover our output without accepting or overwriting another file.
    if (!stored || ![destination isKindOfClass:[NSString class]] ||
        link(source.fileSystemRepresentation, destination.fileSystemRepresentation) != 0) {
      result([FlutterError errorWithCode:@"publish" message:@"Could not save the MP4. A file may already use this name." details:nil]);
    } else { result(nil); }
    return;
  }
  NSArray *arguments = args[@"arguments"];
  if (![key isKindOfClass:[NSString class]] || ![arguments isKindOfClass:[NSArray class]] || _sessions[key]) {
    result([FlutterError errorWithCode:@"arguments" message:@"Invalid conversion request" details:nil]);
    return;
  }
  for (id argument in arguments) {
    if (![argument isKindOfClass:[NSString class]]) {
      result([FlutterError errorWithCode:@"arguments" message:@"Invalid conversion request" details:nil]); return;
    }
  }
  if ([call.method isEqualToString:@"probe"]) {
    FFprobeSession *session = [FFprobeKit executeWithArgumentsAsync:arguments withCompleteCallback:^(FFprobeSession *session) {
      BOOL success = [ReturnCode isSuccess:[session getReturnCode]];
      NSString *output = success ? [session getOutput] : nil;
      dispatch_async(dispatch_get_main_queue(), ^{
        [self->_sessions removeObjectForKey:key];
        if (success) result(output ?: @"{}");
        else result([FlutterError errorWithCode:@"probe" message:@"Could not inspect this video" details:nil]);
      });
    }];
    _sessions[key] = @([session getSessionId]);
    return;
  }
  if ([call.method isEqualToString:@"stream"]) {
    // Live repackaging for the player. It runs for as long as the player is
    // open, including in the background and Picture in Picture, so it takes
    // no background task: playback keeps the app running.
    FFmpegSession *session = [FFmpegKit executeWithArgumentsAsync:arguments withCompleteCallback:^(FFmpegSession *session) {
      BOOL success = [ReturnCode isSuccess:[session getReturnCode]];
      BOOL canceled = [ReturnCode isCancel:[session getReturnCode]];
      dispatch_async(dispatch_get_main_queue(), ^{
        [self->_sessions removeObjectForKey:key];
        result(@{@"status": canceled ? @"canceled" : (success ? @"success" : @"failed")});
      });
    } withLogCallback:^(Log *log) {} withStatisticsCallback:^(Statistics *statistics) {}];
    _sessions[key] = @([session getSessionId]);
    return;
  }
  if ([call.method isEqualToString:@"run"]) {
    _progress[key] = @{};
    __block UIBackgroundTaskIdentifier task = UIBackgroundTaskInvalid;
    __block BOOL expired = NO;
    task = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
      expired = YES;
      NSNumber *session = self->_sessions[key];
      if (session) [FFmpegKit cancel:session.longValue];
      if (task != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:task];
        task = UIBackgroundTaskInvalid;
      }
    }];
    FFmpegSession *session = [FFmpegKit executeWithArgumentsAsync:arguments withCompleteCallback:^(FFmpegSession *session) {
      BOOL success = [ReturnCode isSuccess:[session getReturnCode]];
      BOOL canceled = [ReturnCode isCancel:[session getReturnCode]];
      dispatch_async(dispatch_get_main_queue(), ^{
        [self->_sessions removeObjectForKey:key];
        [self->_progress removeObjectForKey:key];
        if (task != UIBackgroundTaskInvalid) {
          [[UIApplication sharedApplication] endBackgroundTask:task];
          task = UIBackgroundTaskInvalid;
        }
        result(@{@"status": (expired || canceled) ? @"canceled" : (success ? @"success" : @"failed")});
      });
    } withLogCallback:^(Log *log) {} withStatisticsCallback:^(Statistics *statistics) {
      NSDictionary *value = @{@"seconds": @([statistics getTime] / 1000.0), @"bytes": @([statistics getSize])};
      dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_sessions[key]) self->_progress[key] = value;
      });
    }];
    _sessions[key] = @([session getSessionId]);
    return;
  }
  result(FlutterMethodNotImplemented);
}
@end
