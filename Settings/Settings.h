#import <UIKit/UIKit.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSViewController.h>
#import <Preferences/PSSpecifier.h>

#pragma mark - Settings Headers

@interface QRCListController : PSListController
@property (nonatomic, assign) BOOL reloading;
- (NSArray *)localizedSpecifiersWithSpecifiers:(NSArray *)specifiers;
- (NSString *)localizedString:(NSString *)text;
@end

@interface QRCRootViewController : QRCListController
@property (nonatomic, assign) BOOL needReload;
@end

@interface QRCManualViewController : QRCListController
@end

@interface QRCMoreAppsViewController : QRCListController
@end
