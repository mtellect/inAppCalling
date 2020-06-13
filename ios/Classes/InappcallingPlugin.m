#import "InappcallingPlugin.h"
#if __has_include(<inappcalling/inappcalling-Swift.h>)
#import <inappcalling/inappcalling-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "inappcalling-Swift.h"
#endif

@implementation InappcallingPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftInappcallingPlugin registerWithRegistrar:registrar];
}
@end
