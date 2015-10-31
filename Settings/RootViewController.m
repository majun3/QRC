#import "Settings.h"

@interface QRCRootViewController()
@end

@implementation QRCRootViewController

- (id)specifiers {
	if(!_specifiers) {
		_specifiers = [self localizedSpecifiersWithSpecifiers:[self loadSpecifiersFromPlistName:@"Root" target:self]];
	}
	return _specifiers;
}

#pragma mark - Action

- (void)visitWebsite {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://www.clezz.com"]];
}

@end

@implementation QRCManualViewController

- (id)specifiers {
    if(!_specifiers) {
        _specifiers = [self localizedSpecifiersWithSpecifiers:[self loadSpecifiersFromPlistName:@"Manual" target:self]];
    }
    
    return _specifiers;
}
@end