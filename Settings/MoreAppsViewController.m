#import "Settings.h"

@implementation QRCMoreAppsViewController

- (id)specifiers {
	if(!_specifiers) {
		_specifiers = [self localizedSpecifiersWithSpecifiers:[self loadSpecifiersFromPlistName:@"MoreApps" target:self]];
	}
    
	return _specifiers;
}

- (void)qrcWhatsApp {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"cydia://package/com.clezz.qrc.whatsapp"]];
}

- (void)qrcWeChat {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"cydia://package/com.clezz.qrc.wechat"]];
}

- (void)qrcQQ {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"cydia://package/com.clezz.qrc.qq"]];
}

- (void)tage {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"cydia://package/com.clezz.tage"]];
}

- (void)searchplus {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"cydia://package/com.clezz.searchplus"]];
}

- (void)messages {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"cydia://package/com.clezz.messages"]];
}

- (void)quickcall {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"cydia://package/com.clezz.quickcall"]];
}

- (void)quickdo {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"cydia://package/com.clezz.quickdo"]];
}

- (void)dock {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"cydia://package/com.clezz.dock"]];
}

- (void)iunlock {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"cydia://package/com.clezz.iunlock"]];
}

- (void)bulletin {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"cydia://package/com.clezz.bulletin"]];
}

- (void)appstat {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"cydia://package/com.clezz.appstat"]];
}

@end
