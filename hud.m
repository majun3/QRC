
#import "hud.h"

@implementation QRCWindow
// 8.x
- (BOOL)_shouldCreateContextAsSecure {
    return YES;
}
@end

static QRCWindow *window = nil;
static UIProgressHUD *busyIndicator = nil;

BOOL IsShowHUD(void) {
    return busyIndicator != nil;
}

void ShowHUD(void) {
    UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
    
    window = [[QRCWindow alloc] initWithFrame:keyWindow.frame];
    window.windowLevel = 10000;
    window.backgroundColor = [UIColor clearColor];
    window.hidden = NO;
    
    busyIndicator = [[UIProgressHUD alloc] initWithFrame:CGRectMake((window.frame.size.width - 60.0) / 2, (window.frame.size.height - 60.0) / 2, 60.0, 60.0)];
    [busyIndicator setShowsText:NO];
    [busyIndicator showInView:window];
}

void HideHUD(void) {
    if (busyIndicator) {
        [busyIndicator hide];
        busyIndicator = nil;
        
        window.hidden = YES;
        window = nil;
    }
}