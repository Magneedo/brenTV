#import <Flutter/Flutter.h>

@interface IosMediaConverter : NSObject
- (instancetype)initWithMessenger:(NSObject<FlutterBinaryMessenger> *)messenger;
@end
