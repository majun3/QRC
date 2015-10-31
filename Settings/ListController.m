#import "Settings.h"

@implementation QRCListController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = [self localizedString:[self.specifier propertyForKey:@"label"]];
}

- (void)reloadSpecifiers {
    self.reloading = YES;
    [super reloadSpecifiers];
    self.reloading = NO;
}

- (NSArray *)specifiers {
	if(!_specifiers) {
		_specifiers = [[self localizedSpecifiersWithSpecifiers:[self loadSpecifiersFromPlistName:@"Root" target:self]] copy];
	}
	return _specifiers;
}

- (void)setTitle:(NSString *)title {
    super.title = [self localizedString:title];
}

- (NSArray *)localizedSpecifiersWithSpecifiers:(NSArray *)specifiers {
	for (PSSpecifier *curSpec in specifiers) {
		NSString *name = [curSpec name];
		if(name) {
			[curSpec setName:[[self bundle] localizedStringForKey:name value:name table:nil]];
		}
		NSString *footerText = [curSpec propertyForKey:@"footerText"];
		if(footerText)
			[curSpec setProperty:[[self bundle] localizedStringForKey:footerText value:footerText table:nil] forKey:@"footerText"];
		id titleDict = [curSpec titleDictionary];
		if(titleDict) {
			NSMutableDictionary *newTitles = [[NSMutableDictionary alloc] init];
			for(NSString *key in titleDict) {
				NSString *value = [titleDict objectForKey:key];
				[newTitles setObject:[[self bundle] localizedStringForKey:value value:value table:nil] forKey: key];
			}
			[curSpec setTitleDictionary:newTitles];
		}
	}
	return specifiers;
}

- (NSString *)localizedString:(NSString *)text {
    return [[self bundle] localizedStringForKey:text value:text table:nil];
}

- (NSString *)navigationTitle {
	return [self localizedString:[super navigationTitle]];
}

@end
