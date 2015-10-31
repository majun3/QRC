#import <AudioToolbox/AudioToolbox.h>
#import <MobileCoreServices/MobileCoreServices.h>

#import "substrate.h"
#import "libqrc.h"

#import "headers.h"
#import "Helper.h"
#import "hud.h"
#import "ContactsViewController.h"
#import "PhotoPickerController.h"

// MARK: - QRCBaseTweak

@implementation QRCBaseTweak

- (void)registerRetryUserNotificationSettings {
    UIMutableUserNotificationAction *action = [[UIMutableUserNotificationAction alloc] init];
    action.identifier = QRCRetryUnsentMessageKey;
    action.title = QRCLocalizedString(@"Retry");
    action.activationMode = UIUserNotificationActivationModeBackground;
    action.destructive = YES;
    action.authenticationRequired = NO;
    
    UIMutableUserNotificationCategory *category = [[UIMutableUserNotificationCategory alloc] init];
    category.identifier = QRCRetryUnsentMessageKey;
    [category setActions:@[action] forContext:UIUserNotificationActionContextDefault];
    NSSet *categories = [NSSet setWithObjects:category, nil];
    
    UIUserNotificationType notificationType = UIUserNotificationTypeSound | UIUserNotificationTypeAlert;
    UIUserNotificationSettings *notificationSettings = [UIUserNotificationSettings settingsForTypes:notificationType categories:categories];
    
    [[UIApplication sharedApplication] registerUserNotificationSettings:notificationSettings];
}

- (void)sendUnsentLocalNotificationWithUserID:(NSString *)userID messageID:(NSString *)messageID messageText:(NSString *)messageText {
    [self registerRetryUserNotificationSettings];
    
    UILocalNotification *localNotification = [[UILocalNotification alloc] init];
    localNotification.category = QRCRetryUnsentMessageKey;
    localNotification.alertBody = [NSString stringWithFormat:QRCLocalizedString(@"⚠️ Failed to send message \"%@\""), messageText];
    localNotification.soundName = UILocalNotificationDefaultSoundName;
    localNotification.applicationIconBadgeNumber = 0;
    localNotification.userInfo = @{QRCUserIDKey: userID, QRCMessageIDKey: messageID};
    
    [[UIApplication sharedApplication] presentLocalNotificationNow:localNotification];
}

- (void)cancelAllUnsentLocalNotifications {
    for (UILocalNotification *notification in [[UIApplication sharedApplication] scheduledLocalNotifications]) {
        if ([notification.category isEqualToString:QRCRetryUnsentMessageKey]) {
            [[UIApplication sharedApplication] cancelLocalNotification:notification];
        }
    }
}

- (void)sendSentResultMessage:(BOOL)result {
    NSDictionary *userInfo = @{QRCMessageIDKey: @(QRCMessageIDSendResult), QRCResultKey: @(result)};
    [QRCMessageHandler sendMessageName:QRCMessageNameSpringBoard userInfo:userInfo];
}

@end

// MARK: - Constants

#define AppId @"com.clezz.qrc"
#define MessagesNotificationIdentifier @"com.apple.mobilesms.notification"
#define MessagesNotificationProcessName @"MessagesNotificationViewService"
#define AssertiondProcessName @"assertiond"

#define QRCAppIsRunningKey @"appIsRunning"
#define QRCComposeModeKey @"composeMode"
#define QRCActionKey @"action"
#define QRCColorKey  @"color"

// MARK: - Variables

NSUserDefaults *prefs = nil;
static BOOL messagesLoaded = NO;
static BOOL photoPickerPresented = NO;

// SpringBoard
static BOOL finishLaunching = NO;
static BOOL idleSleepFired = NO;

static BBServer *bbServer;
static NSMutableDictionary *tweaks = nil;
static NSMutableDictionary *processAssertions = nil;

BOOL needRefreshContacts = NO;
NSString *currentAppIdentifier = nil;
NSString *currentProcessName = nil;
static NSDictionary *currentColor = nil;
static NSMutableArray *customColors = nil;
static const NSInteger QRCColorType = 100;
static NSInteger retryCount = 0;
static UIInterfaceOrientation frontOrientation = UIInterfaceOrientationPortrait;

static SBBannerContainerViewController *activeContainerController = nil;

// ViewService

static BOOL canBecomeFirstResponder = NO;
static BOOL shouldChangeBalloonColor = NO;
static QRCInlineReplyViewController *activeReplyController = nil;

// MARK: - helper

static inline CKBalloonColor GetColorType(UIColor *color) {
    NSUInteger index = [customColors indexOfObject:color];
    if (index == NSNotFound) {
        if (customColors.count >= (UINT8_MAX + 1 - QRCColorType)) {
            [customColors removeObjectAtIndex:0];
        }
        [customColors addObject:color];
        index = customColors.count - 1;
    }

    return QRCColorType + index;
}

static inline UIColor * ColorFromString(NSString *string) {
    CGFloat red = 0, green = 0, blue = 0, alpha = 0;
    if (string.length == 6) {
        string = [string stringByAppendingString:@"ff"];
    }
    if (string.length == 8) {
        unsigned int colorValue;
        [[NSScanner scannerWithString:string] scanHexInt:&colorValue];
        red = ((colorValue >> 24) & 0xff) / 255.f;
        green = ((colorValue >> 16) & 0xff) / 255.f;
        blue = ((colorValue >> 8) & 0xff) / 255.f;
        alpha = ((colorValue >> 0) & 0xff) / 255.f;
    }
    return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}

static inline NSString * StringFromColor(UIColor *color) {
    CGFloat red = 0, green = 0, blue = 0, alpha = 0;
    [color getRed:&red green:&green blue:&blue alpha:&alpha];
    return [NSString stringWithFormat:@"%02x%02x%02x%02x", (unsigned int)(red * 255), (unsigned int)(green * 255), (unsigned int)(blue * 255), (unsigned int)(alpha * 255)];
}

static inline UIImage * GetAppSmallIcon(NSString *displayIdentifier) {
    UIImage *icon = nil;
    if ([UIImage respondsToSelector:@selector(_applicationIconImageForBundleIdentifier:roleIdentifier:format:scale:)]) {
        icon = [UIImage _applicationIconImageForBundleIdentifier:displayIdentifier roleIdentifier:nil format:0 scale:[UIScreen mainScreen].scale];
    } else {
        icon = [UIImage _applicationIconImageForBundleIdentifier:displayIdentifier format:0 scale:[UIScreen mainScreen].scale];
    }
    return icon;
}

static inline BOOL IsComposeMode(SBBannerContainerViewController *controller) {
    BOOL composeMode = controller._bulletin.context[QRCComposeModeKey] != nil;
    return composeMode;
}

// MARK: - Settings

static inline BOOL IsSimpleMode(id controller) {
    NSString *key = nil;
    if ([controller isKindOfClass:NSClassFromString(@"SBBannerContainerViewController")]) {
        key = IsComposeMode(controller) ? QRCSimpleModeComposeKey : QRCSimpleModeReplyKey;
    } else if ([controller isKindOfClass:NSClassFromString(@"QRCInlineReplyViewController")]) {
        key = [(QRCInlineReplyViewController*)controller isComposeMode] ? QRCSimpleModeComposeKey : QRCSimpleModeReplyKey;
    }
    
    BOOL simpleMode = [prefs boolForKey:key];

    return (simpleMode && !messagesLoaded);
}

static inline UIImage * GetComposeIcon(NSString *name) {
    UIImage *image = nil;
    
    id<QRCTweak> tweak = tweaks[name];
    if (tweak) {
        if ([tweak respondsToSelector:@selector(composeIcon)]) {
            image = tweak.composeIcon;
        } else {
            NSString *appIdentifier = tweak.information[QRCAppIdentifierKey];
            image = GetAppSmallIcon(appIdentifier);
        }
    }
    
    return image;
}

static inline NSUserDefaults * GetTweakPreferences(NSString *name) {
    
    id<QRCTweak> tweak = tweaks[name];
    if (tweak) {
        NSString *packageIdentifier = tweak.information[QRCPackageIdentifierKey];
        NSUserDefaults *preferences = [[NSUserDefaults alloc] initWithSuiteName:packageIdentifier];
        if ([preferences objectForKey:QRCEnabledKey] == nil) {
            [preferences registerDefaults:@{QRCEnabledKey: @(YES), QRCComposeIconKey: @(YES), QRCAuthenticationRequiredKey: @(NO)}];
        }
        if ([preferences objectForKey:QRCAuthenticationRequiredKey] == nil) {
            [preferences setBool:NO forKey:QRCAuthenticationRequiredKey];
        }
        [preferences synchronize];
        
        return preferences;
    }
    
    return nil;
}

static inline BOOL GetTweakBoolPreference(NSString *name, NSString *key) {
    NSUserDefaults *preferences = GetTweakPreferences(name);
    if (preferences) {
        BOOL value = [preferences boolForKey:key];
        preferences = nil;
        return value;
    }
    return NO;
}

static inline BOOL PreferenceEnabled(NSString *name) {
    return GetTweakBoolPreference(name, QRCEnabledKey);
}

static inline BOOL PreferenceComposeIcon(NSString *name) {
    return GetTweakBoolPreference(name, QRCComposeIconKey);
}

static inline BOOL PreferenceAuthenticationRequired(NSString *name) {
    return GetTweakBoolPreference(name, QRCAuthenticationRequiredKey);
}

static inline void ShowFailureAlert(NSString *appIdentifier) {
    NSString *appName = SBSCopyLocalizedApplicationNameForDisplayIdentifier(appIdentifier);
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:appName message:QRCLocalizedString(@"Launching application fails, please launch manually!") delegate:nil cancelButtonTitle:QRCLocalizedString(@"Close") otherButtonTitles:nil];
    [alert show];
}

extern "C" void AudioServicesPlaySystemSoundWithVibration(SystemSoundID soundID, NSMutableDictionary *dict, NSMutableDictionary *dict2);
static inline void PlayVibration() {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:[NSArray arrayWithObjects:[NSNumber numberWithBool:YES], [NSNumber numberWithFloat:70.0], nil] forKey:@"VibePattern"];
    [dict setObject:[NSNumber numberWithFloat:1.0f] forKey:@"Intensity"];
    AudioServicesPlaySystemSoundWithVibration(kSystemSoundID_Vibrate, nil, dict);
}

static inline void PlaySound(BOOL result) {
    static SystemSoundID soundID = 0;
    NSString *path = result ? @"/System/Library/Audio/UISounds/SentMessage.caf" : @"/System/Library/Audio/UISounds/SIMToolkitNegativeACK.caf";
    AudioServicesCreateSystemSoundID((__bridge CFURLRef)[NSURL fileURLWithPath:path], &soundID);
    AudioServicesPlaySystemSound(soundID);
}

// MARK: - Register

static void QRCRegisterTweak(NSString *name, id<QRCTweak> tweak) {
    if (tweaks == nil) tweaks = [[NSMutableDictionary alloc] init];
    tweaks[name] = tweak;
    ALog(@"Register tweak %@ for name %@", tweak, name);
}

void QRCRegisterTweak(id<QRCTweak> tweak) {
    QRCRegisterTweak(tweak.information[QRCPackageIdentifierKey], tweak);
}

void QRCUnregisterTweak(NSString *name) {
    if (tweaks == nil) tweaks = [[NSMutableDictionary alloc] init];
    id<QRCTweak> tweak = tweaks[name];
    ALog(@"Unregister tweak %@ for name %@", tweak, name);
    [tweaks removeObjectForKey:name];
    tweak = nil;
}

// MARK: - ProcessAssertion
static inline void CreateProcessAssertionIfNeeded(NSString *appIdentifier, NSString *processName) {
    
    int PID = PIDForProcessNamed(processName);
    if (PID <= 0) {
        LaunchAppInBackground(appIdentifier, processName);
        CreateProcessAssertionIfNeeded(appIdentifier, processName);
        return;
    }
    
    BKSProcessAssertion *savedProcessAssertion = processAssertions[appIdentifier];
    if (savedProcessAssertion && !savedProcessAssertion.valid) {
        [processAssertions removeObjectForKey:appIdentifier];
        [savedProcessAssertion invalidate];
        savedProcessAssertion = nil;
    }

    if (processAssertions[appIdentifier] == nil) {

        if (idleSleepFired) {
            NSDictionary *userInfo = @{QRCMessageIDKey: @(QRCMessageIDSetActivate)};
            [QRCMessageHandler sendMessageName:QRCMessageNameApplication appIdentifier:appIdentifier userInfo:userInfo];
            idleSleepFired = NO;
        }
        
        ProcessAssertionFlags flags = ProcessAssertionFlagPreventSuspend | ProcessAssertionFlagPreventThrottleDownCPU | ProcessAssertionFlagAllowIdleSleep | ProcessAssertionFlagWantsForegroundResourcePriority;
        
        BKSProcessAssertion *processAssertion = [[NSClassFromString(@"BKSProcessAssertion") alloc] initWithPID:PID flags:flags reason:kProcessAssertionReasonBackgroundUI name:processName withHandler:^(BOOL valid) {
        }];
        
        if (processAssertions == nil) processAssertions = [[NSMutableDictionary alloc] init];
        [processAssertions setObject:processAssertion forKey:appIdentifier];
    }
}

static inline void InvalidateProcessAssertion(NSString *appIdentifier) {
    if (processAssertions[appIdentifier] != nil) {
        __block BKSProcessAssertion *tmp = processAssertions[appIdentifier];
        [processAssertions removeObjectForKey:appIdentifier];
        QRCDispatchAfter(3.0, ^{
            [tmp invalidate];
            tmp = nil;
        });
    }
}

// MARK: - Reply / Compose

static inline NSString * GetNotificationUserIDKey(NSString *appIdentifier) {
    NSString *notificationUserIDKey = nil;
    for (id<QRCTweak> tweak in tweaks.allValues) {
        if ([tweak.information[QRCAppIdentifierKey] isEqualToString:appIdentifier]) {
            notificationUserIDKey = tweak.information[QRCNotificationUserIDKey];
            break;
        }
    }
    return notificationUserIDKey;
}

static inline NSString * GetUserIdentifier(NSString *appIdentifier, BBBulletin *bulletin) {
    
    NSString *userIdentifier = nil;
    
    NSString *notificationType = bulletin.context[@"notificationType"];
    
    if (notificationType) {
        
        NSDictionary *userInfo = nil;
        
        if ([notificationType isEqualToString:@"AppNotificationRemote"]) {
            userInfo = bulletin.context[@"remoteNotification"];
        } else if ([notificationType isEqualToString:@"AppNotificationLocal"] && bulletin.context[@"localNotification"]) {
            UILocalNotification *localNotification = [NSKeyedUnarchiver unarchiveObjectWithData:bulletin.context[@"localNotification"]];
            userInfo = localNotification.userInfo;
        }

        NSString *notificationUserIDKey = GetNotificationUserIDKey(appIdentifier);
        for (NSString *userKey in [notificationUserIDKey componentsSeparatedByString:@"|"]) {
            userIdentifier = userInfo[userKey];
            if (!userIdentifier) userIdentifier = userInfo[@"aps"][userKey];
            if (userIdentifier) break;
        }

        if (!userIdentifier) {
            if ([notificationType isEqualToString:@"AppNotificationRemote"]) {
                NSString *alert = userInfo[@"aps"][@"alert"];
                userIdentifier = [alert componentsSeparatedByString:@":"].firstObject;
            } else {
                userIdentifier = userInfo[@"aps"][@"alert"][@"title"];
            }
        }
        
        if (userIdentifier) {
            NSArray *components = [userIdentifier componentsSeparatedByString:@"|"];
            if (components.count > 1) {
                userIdentifier = [NSString stringWithFormat:@"%@|%@", components[0], components[1]];
            }
        }
    }
    
    return userIdentifier;
}

void QRCModifyBulletinRequest(BBBulletinRequest *request, NSDictionary *appInfo)
{
    if (IS_IPAD || !appInfo) return;
    
    NSString *appIdentifier = appInfo[QRCAppIdentifierKey];
    NSString *processName = appInfo[QRCProcessNameKey];
    
    NSString *sectionID = request.sectionID;
    if ([sectionID isEqualToString:appIdentifier])
    {
        NSString *userIdentifier = nil;
        if (request.context[@"notificationType"]) {
            userIdentifier = GetUserIdentifier(appIdentifier, request);
            if (!userIdentifier) return;
            else [request setContextValue:userIdentifier forKey:QRCUserIDKey];
        }
        
        [request setContextValue:appIdentifier forKey:QRCAppIdentifierKey];
        [request setContextValue:processName forKey:QRCProcessNameKey];
        [request setContextValue:@(AppIsRunning(processName)) forKey:QRCAppIsRunningKey];
        
        // balloonColor
        id<QRCTweak> tweak = tweaks[appInfo[QRCPackageIdentifierKey]];
        if (tweak && [tweak respondsToSelector:@selector(balloonColor)]) {
            NSMutableDictionary *colors = [NSMutableDictionary dictionary];
            [tweak.balloonColor.allKeys enumerateObjectsUsingBlock:^(NSString *key, NSUInteger index, BOOL *stop) {
                colors[key] = StringFromColor(tweak.balloonColor[key]);
            }];
            [request setContextValue:colors forKey:QRCColorKey];
        }
        
        [request.supplementaryActionsByLayout.allKeys enumerateObjectsUsingBlock:^(NSNumber *layout, NSUInteger index, BOOL *stop) {
            [request setSupplementaryActions:nil forLayout:layout.integerValue];
        }];
        
        BBAction *action = [BBAction actionWithIdentifier:QRCActionKey];
        action.actionType = 7;
        action.appearance = [BBAppearance appearanceWithTitle:QRCLocalizedString(@"Reply")];
        action.remoteServiceBundleIdentifier = MessagesNotificationIdentifier;
        action.remoteViewControllerClassName = @"QRCInlineReplyViewController";
        action.authenticationRequired = PreferenceAuthenticationRequired(appInfo[QRCPackageIdentifierKey]);
        action.activationMode = 1;
        [request setSupplementaryActions:@[action]];

        BBButton *reply = [BBButton buttonWithTitle:QRCLocalizedString(@"Reply") action:action identifier:QRCActionKey];
        request.buttons = @[reply];

        if (retryCount == 0 && activeContainerController && !activeContainerController.contactViewController.textField.isFirstResponder && !IsSimpleMode(activeContainerController)) {
            
            NSString *activeAppIdentifier = activeContainerController._bulletin.context[QRCAppIdentifierKey];
            NSString *activeUserIdentifier = activeContainerController._bulletin.context[QRCUserIDKey];
            if (!activeUserIdentifier) activeUserIdentifier = activeContainerController.contactViewController.selectedContact[QRCUserIDKey];
            
            if (!activeAppIdentifier || !activeUserIdentifier || !userIdentifier) return;
            
            if ([activeAppIdentifier isEqualToString:appIdentifier] && ([activeUserIdentifier isEqualToString:userIdentifier] || [activeUserIdentifier hasPrefix:userIdentifier] || [userIdentifier hasPrefix:activeUserIdentifier])) {
                retryCount++;
                [QRCMessageHandler sendMessageName:QRCMessageNameViewService userInfo:@{QRCMessageIDKey: @(QRCMessageIDLoadMessages)} reply:QRCMessageNameSpringBoard handler:^(NSDictionary *userInfo) {
                    retryCount = 0;
                }];
            }
        }
    }
}

static inline void RealPresentComposer(NSDictionary *appInfo) {
    
    NSString *appIdentifier = appInfo[QRCAppIdentifierKey];
    NSString *processName = appInfo[QRCProcessNameKey];
    
    if (!finishLaunching) return;
    
    if (!AppIsRunning(processName)) {
        
        needRefreshContacts = YES;
        retryCount++;
        if (retryCount >= 3) {
            retryCount = 0;
            HideHUD();
            ShowFailureAlert(appIdentifier);
            return;
        }
        
        if (!IsShowHUD()) ShowHUD();
        
        CreateProcessAssertionIfNeeded(appIdentifier, processName);
        QRCDispatchAfter(1.8, ^{ RealPresentComposer(appInfo); });
        
        return;
    }
    
    retryCount = 0;
    HideHUD();
    
    BBBulletinRequest *bulletin = [[BBBulletinRequest alloc] init];
    [bulletin generateNewBulletinID];
    bulletin.sectionID = appIdentifier;
    bulletin.title = SBSCopyLocalizedApplicationNameForDisplayIdentifier(appIdentifier);
    bulletin.message = @"";
    bulletin.defaultAction = [BBAction actionWithLaunchBundleID:appIdentifier];
    
    [bulletin setContextValue:@(YES) forKey:QRCComposeModeKey];
    
    QRCModifyBulletinRequest(bulletin, appInfo);
    
    BBAction *action = bulletin.supplementaryActions.firstObject;
    
    SBBulletinBannerController *bulletinBannerController = (SBBulletinBannerController*)[NSClassFromString(@"SBBulletinBannerController") sharedInstance];
    dispatch_async(dispatch_get_main_queue(), ^{
        [bulletinBannerController modallyPresentBannerForBulletin:bulletin action:action];
    });
}

void QRCPresentComposer(NSDictionary *appInfo)
{
    if (IS_IPAD) return;
    
    SBBannerController *bannerController = [NSClassFromString(@"SBBannerController") sharedInstance];
    if (bannerController._bannerContext && [bannerController._bannerContext.item respondsToSelector:@selector(seedBulletin)] && bannerController._bannerContext.item.seedBulletin.context[QRCComposeModeKey] != nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [bannerController dismissBannerWithAnimation:YES reason:1];
        });
    } else {
        if (bannerController.isShowingBanner || bannerController.isShowingModalBanner) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [bannerController dismissBannerWithAnimation:YES reason:1];
            });
            QRCDispatchAfter(0.3, ^{ RealPresentComposer(appInfo); });
        } else {
            if (bannerController._bannerContext == nil) RealPresentComposer(appInfo);
        }
    }
}

static inline BOOL IsShowingModalBanner(void) {
    SBBannerController *bannerController = [NSClassFromString(@"SBBannerController") sharedInstance];
    return bannerController.isShowingModalBanner;
}

static inline void ClearNotifications(NSDictionary *userInfo) {
    dispatch_sync(__BBServerQueue, ^{
        NSString *appIdentifier = userInfo[QRCAppIdentifierKey];
        NSString *userIdentifier = userInfo[QRCUserIDKey];

        BBDataProvider *dataProvider = [bbServer dataProviderForSectionID:appIdentifier];
        NSSet *bulletins = [bbServer bulletinsRequestsForBulletinIDs:[bbServer allBulletinIDsForSectionID:appIdentifier]];
        NSInteger remainingCount = 0;
        for (BBBulletinRequest *bulletin in bulletins) {
            if ([GetUserIdentifier(appIdentifier, bulletin) isEqualToString:userIdentifier]) {
                BBDataProviderWithdrawBulletinWithPublisherBulletinID(dataProvider, bulletin.publisherBulletinID);
            } else {
                remainingCount++;
            }
        }
        BBDataProviderSetApplicationBadge(dataProvider, remainingCount);
    });
}

static inline NSDictionary *SpringBoardMessageHandler(NSDictionary *userInfo) {
    
    QRCMessageID messageId = (QRCMessageID)[userInfo[QRCMessageIDKey] intValue];
    
    if (messageId == QRCMessageIDAppWillTerminate) {
        ClearImageCache();
    } else if (messageId == QRCMessageIDSendResult) {
        if (userInfo[QRCResultKey]) {
            BOOL result = [userInfo[QRCResultKey] boolValue];
            if (result) {
                if ([prefs boolForKey:QRCPlaySoundKey]) PlaySound(result);
                if ([prefs boolForKey:QRCVibrateKey]) PlayVibration();
            } else {
                PlaySound(result);
                PlayVibration();
            }
        }
    } else if (messageId == QRCMessageIDSwitchToSelectContact) {
        if (!IsComposeMode(activeContainerController)) {
            NSMutableDictionary *context = activeContainerController._bulletin.context.mutableCopy;
            context[QRCComposeModeKey] = [NSNumber numberWithBool:YES];
            activeContainerController._bulletin.context = context;

            activeContainerController.bannerContextView.separatorVisible = YES;
            activeContainerController.bannerContextView.grabberVisible = NO;
            activeContainerController.contactViewController.view.hidden = NO;
            
            [activeContainerController.bannerContextView _updateContentAlpha];
            SBDefaultBannerView *_contentView = MSHookIvar<SBDefaultBannerView*>(activeContainerController.bannerContextView, "_contentView");
            [_contentView setNeedsLayout];
        }

        [activeContainerController.contactViewController.textField becomeFirstResponder];
        
    } else if (messageId == QRCMessageIDLoadMessages) {
        messagesLoaded = [userInfo[QRCResultKey] boolValue];
    } else if (messageId == QRCMessageIDPhotoPicker) {
        photoPickerPresented = [userInfo[QRCResultKey] boolValue];
    } else if (messageId == QRCMessageIDClearNotifications) {
        ClearNotifications(userInfo);
    }
    
    return nil;
}

static inline void SpringBoardRegisterMessageName(void) {
    [QRCMessageHandler registerMessageName:QRCMessageNameSpringBoard handler:^NSDictionary *(NSDictionary *userInfo) {
        return SpringBoardMessageHandler(userInfo);
    }];
}

static inline void SpringBoardInit(void) {
    SpringBoardRegisterMessageName();

    prefs = [[NSUserDefaults alloc] initWithSuiteName:AppId];
    if ([prefs objectForKey:QRCReturnAsSendKey] == nil) {
        [prefs registerDefaults:@{QRCSimpleModeComposeKey: @(NO), QRCSimpleModeReplyKey: @(NO), QRCQuitAppWhenSleepKey: @(NO), QRCReturnAsSendKey: @(NO), QRCPlaySoundKey: @(YES), QRCVibrateKey: @(NO)}];
    }
    if ([prefs objectForKey:QRCDismissAfterSendKey] == nil) {
        [prefs setBool:YES forKey:QRCDismissAfterSendKey];
    }
    if ([prefs objectForKey:QRCRecentContactLimitKey] == nil) {
        [prefs setInteger:15 forKey:QRCRecentContactLimitKey];
    }
    [prefs synchronize];
}

static inline void AddComposeButton(SBNotificationCenterViewController *controller) {

    NSMutableDictionary *buttons = [NSMutableDictionary dictionary];
    UIView *contentView = MSHookIvar<UIView*>(controller, "_contentView");
    
    for (UIView *button in contentView.subviews) {
        if (button.restorationIdentifier != nil) buttons[button.restorationIdentifier] = button;
    }
    
    CGRect frame = CGRectMake(contentView.frame.size.width, contentView.frame.size.height - 64, 24, 24);
    CGFloat x = contentView.frame.size.width - frame.size.width - 20;
    
    for (NSString *name in tweaks.allKeys) {
        if (PreferenceEnabled(name) && PreferenceComposeIcon(name) && GetComposeIcon(name)) {
            if (buttons[name] == nil) {
                UIButton *button = [[UIButton alloc] initWithFrame:frame];
                button.imageEdgeInsets = UIEdgeInsetsMake(1, 1, 1, 1);
                [button setImage:GetComposeIcon(name) forState:UIControlStateNormal];
                [button addTarget:controller action:@selector(qrc_handleTap:) forControlEvents:UIControlEventTouchUpInside];
                button.showsTouchWhenHighlighted = YES;
                button.restorationIdentifier = name;
                [contentView addSubview:button];
                buttons[name] = button;
            }
        } else {
            UIButton *button = buttons[name];
            if (button) {
                [button removeFromSuperview];
                [buttons removeObjectForKey:name];
            }
        }
    }
    
    for (UIButton *button in buttons.allValues) {
        button.frame = CGRectMake(x, contentView.frame.size.height - 64, button.frame.size.width, button.frame.size.height);
        x = x - frame.size.width - 18;
    }
    
    buttons = nil;
}

// MARK: - SpringBoardHook

%group SpringBoardHook

%hook BBServer
- (id)init {
    id orig = bbServer = %orig();
    return orig;
}
%end

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)arg1 {
    %orig;
    finishLaunching = YES;
}
- (void)didReceiveMemoryWarning {
    ALog(@"=========================== didReceiveMemoryWarning ================================");
    %orig();
    ClearImageCache();
}
%end

%hook SBBacklightController
- (void)allowIdleSleep {
    %orig();

    if ([[objc_getClass("SBLockScreenManager") sharedInstance] isUILocked]) {

        idleSleepFired = YES;
        ClearImageCache();

        for (BKSProcessAssertion *assertion in processAssertions.allValues) {
            [assertion invalidate];
        }
        [processAssertions removeAllObjects];
        
        if ([prefs boolForKey:QRCQuitAppWhenSleepKey]) {
            for (id<QRCTweak> tweak in tweaks.allValues) {
                TerminateApp(tweak.information[QRCAppIdentifierKey]);
            }
        }
    }
}
%end

%hook SBBannerController
- (void)_handleGestureState:(NSInteger)state location:(CGPoint)location displacement:(CGFloat)displacement velocity:(CGFloat)velocity {
    NSInteger activeGestureType = MSHookIvar<NSInteger>(self, "_activeGestureType");
    if (!self.isShowingModalBanner || activeGestureType != 2) {
        %orig();
    }
}
- (BOOL)gestureRecognizerShouldBegin:(id)arg1 {
    NSInteger activeGestureType = MSHookIvar<NSInteger>(self, "_activeGestureType");
    if (!activeContainerController && (!self.isShowingModalBanner || activeGestureType != 2)) {
        return %orig();
    } else {
        return NO;
    }
}
%end

// MARK: - SBNotificationCenterViewController

%hook SBNotificationCenterViewController
%new
- (void)qrc_handleTap:(UIButton*)sender {
    id<QRCTweak> tweak = tweaks[sender.restorationIdentifier];
    if (tweak) {
        if ([tweak respondsToSelector:@selector(compose)]) [tweak compose];
        else QRCPresentComposer(tweak.information);
    }
}
- (void)viewWillAppear:(BOOL)arg {
    %orig();
    AddComposeButton(self);
}
%end

#pragma mark - SBBannerContainerViewController

%hook SBBannerContainerViewController
%new
- (QRCContactsViewController *)contactViewController {
    return objc_getAssociatedObject(self, @selector(contactViewController));
}
%new
- (void)setContactViewController:(QRCContactsViewController *)value {
    objc_setAssociatedObject(self, @selector(contactViewController), value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%new
- (CGFloat)keyboardHeight {
    CGSize size = MSHookIvar<CGRect>(self, "_keyboardFrame").size;
    
    CGFloat height = size.height;
    if (height == 0) {
        size = [NSClassFromString(@"UIKeyboard") defaultSizeForInterfaceOrientation:frontOrientation];
        height = size.height;
    } else {
        if (OS_VERSION < 9.0f && UIInterfaceOrientationIsLandscape(frontOrientation)) height = size.width;
    }
    
    return height;
}

- (void)loadView {
    %orig();

    BBBulletinRequest *request = self._bulletin;
    NSString *appIdentifier = request.context[QRCAppIdentifierKey];
    NSString *processName = request.context[QRCProcessNameKey];

    if ([request.sectionID isEqualToString:appIdentifier]) {

        NSMutableDictionary *context = request.context.mutableCopy;
        context[QRCAppIsRunningKey] = @(AppIsRunning(processName));
        request.context = context;
        
        CreateProcessAssertionIfNeeded(appIdentifier, processName);
        
        QRCContactsViewController *contactViewController = [[QRCContactsViewController alloc] initWithFrame:CGRectMake(0.0f, 0.0, self.view.bounds.size.width, self.view.bounds.size.height)];
        self.contactViewController = contactViewController;
        contactViewController = nil;
    
        __weak SBBannerContainerViewController *weakSelf = self;
        self.contactViewController.layoutHandler = ^(void) {
            [weakSelf.view setNeedsLayout];
        };
    
        [self addChildViewController:self.contactViewController];
        [self.bannerContextView addSubview:self.contactViewController.view];
        [self.view bringSubviewToFront:self.bannerContextView];
                
        for(UIGestureRecognizer *recognizer in self.bannerContextView.gestureRecognizers) {
            recognizer.delegate = self.contactViewController;
        }
        
        UIView *containerView = MSHookIvar<UIView*>(self, "_containerView"); // = self.view
        for(UIGestureRecognizer *recognizer in containerView.gestureRecognizers) {
            recognizer.delegate = self.contactViewController;
        }
        
        if (IsSimpleMode(self)) {
            UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(qrc_handlePan:)];
            pan.delegate = self.contactViewController;
            [self.view addGestureRecognizer:pan];
            pan = nil;
        }

        if (IsComposeMode(self)) {
            self.bannerContextView.separatorVisible = YES;
            self.bannerContextView.grabberVisible = NO;
            self.contactViewController.view.hidden = NO;
        } else {
            self.contactViewController.view.hidden = YES;
        }
    }
}

%new
- (void)qrc_handlePan:(UIPanGestureRecognizer *)recognizer {
    CGPoint velocity = [recognizer velocityInView:recognizer.view];
    CGPoint translation = [recognizer translationInView:recognizer.view];
    if (IsShowingModalBanner() && recognizer.enabled && recognizer.state == UIGestureRecognizerStateChanged) {
        if (translation.y > 50 && velocity.y > 200.0f) {
            recognizer.enabled = NO;
            messagesLoaded = YES;
            [QRCMessageHandler sendMessageName:QRCMessageNameViewService userInfo:@{QRCMessageIDKey: @(QRCMessageIDLoadMessages)}];
            recognizer.enabled = YES;
        }
    }
}

- (void)viewDidAppear:(BOOL)animated {
    %orig();
    
    NSString *appIdentifier = self._bulletin.context[QRCAppIdentifierKey];
    if ([self._bulletin.sectionID isEqualToString:appIdentifier] && IsComposeMode(self)) {
        [self.contactViewController.textField becomeFirstResponder];
        [self.contactViewController loadContacts];
    }
}

- (void)_noteDidPullDown {
    %orig();
    
    BBBulletinRequest *request = self._bulletin;
    currentAppIdentifier = request.context[QRCAppIdentifierKey];
    currentProcessName = request.context[QRCProcessNameKey];

    if ([self._bulletin.sectionID isEqualToString:currentAppIdentifier]) {
        activeContainerController = nil;
        activeContainerController = self;
        CreateProcessAssertionIfNeeded(currentAppIdentifier, currentProcessName);
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    %orig();
    NSString *appIdentifier = self._bulletin.context[QRCAppIdentifierKey];
    if ([self._bulletin.sectionID isEqualToString:appIdentifier]) {
        if (IsComposeMode(self)) {
            [self.contactViewController.textField resignFirstResponder];
        }
        if (IsShowingModalBanner()) {
            currentAppIdentifier = nil;
            currentProcessName = nil;
        }
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig();
    
    NSString *appIdentifier = self._bulletin.context[QRCAppIdentifierKey];
    if ([self._bulletin.sectionID isEqualToString:appIdentifier]) {
        if (self.contactViewController) {
            [self.contactViewController.view removeFromSuperview];
            [self.contactViewController removeFromParentViewController];
            self.contactViewController = nil;
        }
        
        messagesLoaded = NO;
        activeContainerController = nil;
        InvalidateProcessAssertion(appIdentifier);
    }
}

- (void)_updateMaximumContainerHeightForOrientation:(UIInterfaceOrientation)orientation  {
    frontOrientation = orientation;
    %orig();
}

- (CGFloat)_pullDownViewHeight {
    CGFloat orig = %orig();
    
    NSString *appIdentifier = self._bulletin.context[QRCAppIdentifierKey];
    if ([self._bulletin.sectionID isEqualToString:appIdentifier]) {
        if (orig < 0.0f) orig = 0.0f;
    }
    
    return orig;
}

- (CGFloat)_preferredPullDownViewHeight {
    CGFloat orig = %orig();
    
    NSString *appIdentifier = self._bulletin.context[QRCAppIdentifierKey];
    if ([self._bulletin.sectionID isEqualToString:appIdentifier]) {

        if (IsComposeMode(self)) {
            if ((self.contactViewController.tableView.hidden ==  NO) || (!self.contactViewController.selectedContact && self.contactViewController.textField.isFirstResponder)) {
                orig = 0.0f;
            } else {
                if ((NSInteger)orig <= 0) {
                    if (IsSimpleMode(self)) return photoPickerPresented ? QRCPhotoPickerController.pickerViewHeight : 52.0;
                    orig = self.view.frame.size.height - [self keyboardHeight] - 44.0f;
                }
            }
        } else {
            if (self.canPullDown) {
                if ((NSInteger)orig <= 0) {
                    if (IsSimpleMode(self)) return photoPickerPresented ? QRCPhotoPickerController.pickerViewHeight : 52.0;
                    
                    CGFloat keyboardHeight = [self keyboardHeight] > 320 ? 216 : [self keyboardHeight];
                    CGFloat height = self.view.bounds.size.height;
                    if (height < [self keyboardHeight]) height = self.view.bounds.size.width;
                    orig = height - keyboardHeight - [self _bannerContentHeight];
                }
            }
        }
    }
    
    return orig;
}

- (CGFloat)_miniumBannerContentHeight {
    CGFloat orig = %orig();
    if (IsComposeMode(self)) orig = 44.0;
    return orig;
}

- (CGFloat)preferredMaximumHeight {
    CGFloat orig = %orig();
    
    if (IsComposeMode(self)) {
        CGFloat keyboardHeight = [self keyboardHeight];
        if (orig > self.view.bounds.size.height - keyboardHeight) orig = self.view.bounds.size.height - keyboardHeight;
        if (orig < 0.0) orig = 0.0;
            
        if (!self.contactViewController.selectedContact || self.contactViewController.textField.isFirstResponder) {
            orig = 44.0f * self.contactViewController.contacts.count + 44.0;
            if (orig > self.view.bounds.size.height - keyboardHeight) {
                orig = self.view.bounds.size.height - keyboardHeight;
            }
        } else {
            if (IsSimpleMode(self)) {
                return orig;
            }
        }
    }
    
    return orig;
}

- (CGFloat)_bannerContentHeight {
    CGFloat orig = %orig();
    
    if (IsComposeMode(self)) {
        
        if (IsSimpleMode(self) && !self.contactViewController.textField.isFirstResponder) {
            if (orig < 44.0f || orig > 44.0f) orig = 44.0f;
            return orig;
        }
        
        NSInteger count = self.contactViewController.contacts.count;
        
        CGFloat height = 44.0f * count + 44.0f;
        CGFloat keyboardHeight = [self keyboardHeight];
        if (height > self.view.bounds.size.height - keyboardHeight - [self _preferredPullDownViewHeight]) {
            height = self.view.bounds.size.height - keyboardHeight - [self _preferredPullDownViewHeight];
        }
        if (height < 44.0f) height = 44.0f;
        
        return height;
        
    } else return orig;
}

- (void)viewDidLayoutSubviews {
    %orig();
    if (IsComposeMode(self)) {
        CGFloat height = [self preferredMaximumHeight];

        CGRect frame = self.bannerContextView.frame;
        frame.size.height = height;
        self.bannerContextView.frame = frame;

        CGFloat keyboardHeight = [self keyboardHeight];
        frame = self.contactViewController.tableView.frame;
        frame.size.height = self.view.bounds.size.height - keyboardHeight - 44.0;
        self.contactViewController.tableView.frame = frame;

        self.contactViewController.view.frame = CGRectMake(0.0, 0.0, self.contactViewController.view.frame.size.width, height);
        
        SBBannerContainerView *containerView = MSHookIvar<SBBannerContainerView*>(self, "_containerView");
        frame = containerView.backgroundView.frame;
        frame.origin.y = CGRectGetMaxY(self.bannerContextView.frame);
        frame.size.height = self.view.bounds.size.height - frame.origin.y;
        containerView.backgroundView.frame = frame;
    }
}

- (void)_handleBannerContainerTapGesture:(id)arg1 {
    if (photoPickerPresented) {
        [QRCMessageHandler sendMessageName:QRCMessageNameViewService userInfo:@{QRCMessageIDKey: @(QRCMessageIDPhotoPicker)}];
    } else %orig();
}

%end

%hook SBBannerContextView
- (void)_updateContentAlpha {
    %orig();
    
    if ([self.bannerContext.item respondsToSelector:@selector(seedBulletin)]) {
        BBBulletin *bulletin = self.bannerContext.item.seedBulletin;
        if (bulletin.context[QRCComposeModeKey] != nil) {
            UIView *contentContainerView = MSHookIvar<UIView*>(self, "_contentContainerView");
            CGRect frame = contentContainerView.frame;
            frame.size.height = 44.0;
            frame.origin.y = 0.0;
            contentContainerView.frame = frame;
            
            SBDefaultBannerView *contentView = MSHookIvar<SBDefaultBannerView*>(self, "_contentView");
            frame = contentView.frame;
            frame.size.height = 44.0;
            frame.origin.y = 0.0;
            contentView.frame = frame;
            
            UIView *separatorView = MSHookIvar<UIView*>(self, "_separatorView");
            frame = separatorView.frame;
            frame.origin.y = 44.0;
            separatorView.frame = frame;
            
            separatorView.alpha = 1.0;
        }
    }
}
%end

%hook SBDefaultBannerView
- (void)layoutSubviews {
    %orig();
    if ([self.bannerContext.item respondsToSelector:@selector(seedBulletin)]) {
        BBBulletin *bulletin = self.bannerContext.item.seedBulletin;
        if (bulletin.context[QRCComposeModeKey] != nil) {
            SBDefaultBannerTextView *textView = MSHookIvar<SBDefaultBannerTextView*>(self, "_textView");
            textView.hidden = YES;
            
            UIImageView *iconImageView = MSHookIvar<UIImageView*>(self, "_iconImageView");
            CGRect frame = iconImageView.frame;
            frame.origin.x = 17.5;
            frame.origin.y = 12.0;
            iconImageView.frame = frame;
            
            if (activeContainerController && activeContainerController.contactViewController) {
                iconImageView.hidden = (activeContainerController.contactViewController.selectedContact != nil);
            }
        }
    }
}
%end

%end

@interface CKIMFileTransfer : NSObject
- (id)initWithFileURL:(id)arg1 transcoderUserInfo:(id)arg2;
@end

static inline void setupChatItems(QRCInlineReplyViewController *controller, NSArray *result) {
    
    NSMutableArray *chatItems = [NSMutableArray array];
    controller.conversationViewController.chatItems = chatItems;
    
    [result enumerateObjectsUsingBlock:^(NSDictionary *messageDict, NSUInteger index, BOOL *stop)
    {
        QRCMessageType messageType = [messageDict[QRCTypeKey] intValue];
        NSString *content = messageDict[QRCContentKey];
        NSString *filePath = messageDict[QRCFilePathKey];
        BOOL outgoing = [messageDict[QRCOutgoingKey] boolValue];
        NSDate *timestamp = [NSDate dateWithTimeIntervalSince1970:[messageDict[QRCTimeKey] doubleValue]];

        IMMessageItem *messageItem = [[NSClassFromString(@"IMMessageItem") alloc] init];
        BOOL finished = YES, fromme = outgoing, delivered = YES, read = !outgoing, sent = outgoing;
        messageItem.flags |= (finished << 0x0 | fromme << 0x2 | delivered << 0xc | read << 0xd | sent << 0xf);
        messageItem.time = timestamp;
        messageItem.timeDelivered = timestamp;
        messageItem.timeRead = timestamp;
        messageItem.context = [NSClassFromString(@"IMMessage") messageFromIMMessageItem:messageItem sender:nil subject:nil];

         if (messageDict[QRCErrorKey]) messageItem.errorCode = 4;
        
         if (messageType == QRCMessageTypeText) {
             IMTextMessagePartChatItem *imChatItem = [[NSClassFromString(@"IMTextMessagePartChatItem") alloc] _initWithItem:messageItem text:[[NSAttributedString alloc] initWithString:content] index:0 subject:nil];
             CKChatItem *chatItem = [controller.conversationViewController chatItemWithIMChatItem:imChatItem];
             if (chatItem.transcriptDrawerText == nil) chatItem.transcriptDrawerText = [[NSAttributedString alloc] initWithString:@""];
             chatItem.userIdentifier = messageDict[QRCUserIDKey];
             if (chatItem) [chatItems addObject:chatItem];
         } else if (messageType == QRCMessageTypeImage) {
             
             CKMediaObjectManager *manager = [NSClassFromString(@"CKMediaObjectManager") sharedInstance];
             CKMediaObject *mediaObject = nil;
             NSString *filename = @"image.jpg";
             id UTITypes = [NSClassFromString(@"CKImageMediaObject") UTITypes];
             
             if (filePath) {
                 NSData *data = [NSData dataWithContentsOfFile:filePath];
                 mediaObject = [manager mediaObjectWithData:data UTIType:UTITypes filename:filename transcoderUserInfo:nil];
             } else {
                 NSData *data = [[NSData alloc] initWithBase64EncodedString:content options:0];
                 mediaObject = [manager mediaObjectWithData:data UTIType:UTITypes filename:filename transcoderUserInfo:nil];
             }

             if (mediaObject) {
                 NSDictionary *attributes = @{IMMessagePartAttributeName: @(1),
                                              IMFileTransferGUIDAttributeName: mediaObject.transferGUID,
                                              IMFilenameAttributeName: filename,
                                              IMBaseWritingDirectionAttributeName: @(NSWritingDirectionNatural)};
                 messageItem.body = [[NSAttributedString alloc] initWithString:IMAttachmentCharacterString attributes:attributes];
             }
             
         } else if (messageType == QRCMessageTypeAudio) {
             
             CKMediaObject *mediaObject = nil;
             CKMediaObjectManager *manager = [NSClassFromString(@"CKMediaObjectManager") sharedInstance];
             
             NSString *filename = @"audio.amr";
             id UTITypes = [NSClassFromString(@"CKAudioMediaObject") UTITypes];
             
             if (filePath) {
                 NSData *data = [NSData dataWithContentsOfFile:filePath];
                 mediaObject = [manager mediaObjectWithData:data UTIType:UTITypes filename:filename transcoderUserInfo:nil];
             } else {
                 NSData *data = [[NSData alloc] initWithBase64EncodedString:content options:0];
                 mediaObject = [manager mediaObjectWithData:data UTIType:UTITypes filename:filename transcoderUserInfo:nil];
             }
             
             if (mediaObject) {
                 NSDictionary *attributes = @{IMMessagePartAttributeName: @(0),
                                              IMFileTransferGUIDAttributeName: mediaObject.transferGUID,
                                              IMFilenameAttributeName: filename};
                 messageItem.body = [[NSAttributedString alloc] initWithString:IMAttachmentCharacterString attributes:attributes];
             }
         } else if (messageType == QRCMessageTypeVideo) {
             
             CKMediaObjectManager *manager = [NSClassFromString(@"CKMediaObjectManager") sharedInstance];
             CKMediaObject *mediaObject = nil;
             NSString *filename = @"video.mp4";
             id UTITypes = [NSClassFromString(@"CKMovieMediaObject") UTITypes];
             
             if (filePath) {
                 NSData *data = [NSData dataWithContentsOfFile:filePath];
                 mediaObject = [manager mediaObjectWithData:data UTIType:UTITypes filename:filename transcoderUserInfo:nil];
             }
             
             if (mediaObject) {
                 NSDictionary *attributes = @{IMMessagePartAttributeName: @(0),
                                              IMFileTransferGUIDAttributeName: mediaObject.transferGUID,
                                              IMFilenameAttributeName: filename};
                 messageItem.body = [[NSAttributedString alloc] initWithString:IMAttachmentCharacterString attributes:attributes];
             }
             
         } else if (messageType == QRCMessageTypeTime) {
             
             IMDateChatItem *dateChatItem = [[NSClassFromString(@"IMDateChatItem") alloc] _initWithItem:messageItem];
             CKChatItem *chatItem = [controller.conversationViewController chatItemWithIMChatItem:dateChatItem];
             if (chatItem) [chatItems addObject:chatItem];
             
         } else if (messageType == QRCMessageTypeSender) {
             
             NSString *name = content;
             IMHandle *handle = [[NSClassFromString(@"IMHandle") alloc] init];
             
             if (OS_VERSION >= 9.0f) {
                 [[NSClassFromString(@"IMHandleRegistrar") sharedInstance] registerIMHandle:handle];
             }
             
             [handle setFirstName:name lastName:nil fullName:nil andUpdateABPerson:NO];
             IMSenderChatItem *senderChatItem = [[NSClassFromString(@"IMSenderChatItem") alloc] _initWithItem:messageItem handle:handle];
             CKChatItem *chatItem = [controller.conversationViewController chatItemWithIMChatItem:senderChatItem];
             if (chatItem) [chatItems addObject:chatItem];
             
         }
        
         if (messageType != QRCMessageTypeTime && messageType != QRCMessageTypeSender && messageType != QRCMessageTypeText) {
             CKChatItem *chatItem = [controller.conversationViewController chatItemWithIMChatItem:messageItem._newChatItems];
             if (chatItem.transcriptDrawerText == nil) chatItem.transcriptDrawerText = [[NSAttributedString alloc] initWithString:@""];
             chatItem.userIdentifier = messageDict[QRCUserIDKey];
             
             if (chatItem) [chatItems addObject:chatItem];
         }
    }];

    controller.conversationViewController.chatItems = chatItems;
    [controller.conversationViewController refreshData];

    if ([controller isComposeMode] && controller.conversationViewController.view.hidden) [controller interactiveNotificationDidAppear];
    [controller.view setNeedsLayout];
}

enum {
    QRCScrollingStateStopped = 0,
    QRCScrollingStateTriggered,
    QRCScrollingStateLoading
};
typedef NSUInteger QRCScrollingState;

static QRCScrollingState scrollingState = QRCScrollingStateStopped;

static inline void SendClearNotificationsMessage(QRCInlineReplyViewController *controller) {
    NSString *appIdentifier = controller.context[QRCAppIdentifierKey];
    NSString *userIdentifier = controller.context[QRCUserIDKey];

    if (appIdentifier && userIdentifier) {
        [QRCMessageHandler sendMessageName:QRCMessageNameSpringBoard userInfo:@{QRCMessageIDKey : @(QRCMessageIDClearNotifications), QRCAppIdentifierKey: appIdentifier, QRCUserIDKey: userIdentifier}];
    }
}

static inline void LoadChatMessages(QRCInlineReplyViewController *controller) {

    messagesLoaded = YES;
    [QRCMessageHandler sendMessageName:QRCMessageNameSpringBoard userInfo:@{QRCMessageIDKey: @(QRCMessageIDLoadMessages), QRCResultKey: @(messagesLoaded)}];
    
    NSString *identifier = controller.context[QRCUserIDKey];
    
    if (identifier != nil)
    {
        shouldChangeBalloonColor = YES;
        
        NSDictionary *userInfo = @{QRCMessageIDKey: @(QRCMessageIDGetMessages), QRCMessageDataKey: identifier};
        [QRCMessageHandler sendMessageName:QRCMessageNameApplication appIdentifier:currentAppIdentifier userInfo:userInfo reply:QRCMessageNameViewService handler:^(NSDictionary *reply)
         {
             NSArray *result = reply[QRCResultKey];
            if ((controller.conversationViewController.chatItems && controller.conversationViewController.chatItems.count && !result.count))
                QRCDispatchAfter(0.5, ^{ LoadChatMessages(controller); });
            else setupChatItems(controller, result);
             
             scrollingState = QRCScrollingStateStopped;
             [activeReplyController.activityIndicatorView stopAnimating];
             
             SendClearNotificationsMessage(controller);
         }];
    }
}

static inline void SetAvatarView(CKTranscriptBalloonCell *balloonCell, UIImage *image) {
    BOOL show = (image == nil) ? NO : YES;
    balloonCell.wantsContactImageLayout = show;
    if ([balloonCell respondsToSelector:@selector(contactImage)]) {
        balloonCell.contactImage = image;
    } else {
        [balloonCell setShowAvatarView:show withContact:nil preferredHandle:nil avatarViewDelegate:nil];
        if (image) [balloonCell.avatarView.imageButton setImage:image forState:UIControlStateNormal];
    }
}

static inline void configureCell(QRCConversationViewController *conversationViewController, CKTranscriptCell *cell, NSIndexPath *indexPath)
{
    if ([cell isKindOfClass:CKTranscriptMessageCell.class]) {
        CKTranscriptMessageCell *messageCell = (CKTranscriptMessageCell *)cell;

        if ([messageCell isKindOfClass:CKTranscriptBalloonCell.class]) {
            CKTranscriptBalloonCell *balloonCell = (CKTranscriptBalloonCell *)cell;
            CKBalloonView *balloonView = balloonCell.balloonView;
            balloonView.filled = YES;
            
            if ([balloonView isKindOfClass:CKColoredBalloonView.class]) {
                CKColoredBalloonView *coloredBalloonView = (CKColoredBalloonView *)balloonView;
                
                if (currentColor) {
                    BOOL left = coloredBalloonView.orientation == CKBalloonOrientationLeft;
                    NSString *balloonColorKey = left ? QRCLeftBalloonColorKey : QRCRightBalloonColorKey;
                    NSString *textColorKey = left ? QRCLeftTextColorKey : QRCRightTextColorKey;
                    
                    UIColor *balloonColor = currentColor[balloonColorKey] ? ColorFromString(currentColor[balloonColorKey]) : (left ? [UIColor whiteColor] : [UIColor colorWithRed:94.0/255.0 green:166.0/255.0 blue:224.0/255.0 alpha:1.0]);
                    coloredBalloonView.color = GetColorType(balloonColor);
                    
                    if ([balloonView isKindOfClass:CKTextBalloonView.class] && currentColor) {
                        CKTextBalloonView *textBalloonView = (CKTextBalloonView *)coloredBalloonView;
                        NSMutableAttributedString *text = textBalloonView.attributedText.mutableCopy;
                        UIColor *textColor = currentColor[textColorKey] ? ColorFromString(currentColor[textColorKey]) : (left ? [UIColor blackColor] : [UIColor whiteColor]);
                        [text addAttributes:@{NSForegroundColorAttributeName:textColor} range:NSMakeRange(0, text.length)];
                        textBalloonView.attributedText = text;
                    }
                }
            }

            CKMessagePartChatItem *chatItem = (CKMessagePartChatItem *)conversationViewController.chatItems[indexPath.item];
            if (chatItem.userIdentifier != nil) {
                messageCell.wantsContactImageLayout = YES;
                if (CachedImage(chatItem.userIdentifier)) {
                    UIImage *contactImage = (UIImage*)CachedImage(chatItem.userIdentifier);
                    SetAvatarView(balloonCell, contactImage);
                } else {
                    NSDictionary *userInfo = @{ QRCMessageIDKey: @(QRCMessageIDGetAvatar), QRCMessageDataKey : chatItem.userIdentifier };
                    [QRCMessageHandler sendMessageName:QRCMessageNameApplication appIdentifier:currentAppIdentifier userInfo:userInfo reply:QRCMessageNameViewService handler:^(NSDictionary *userInfo) {

                        NSData *data = nil;
                        if (userInfo) {
                            NSString *result = userInfo[QRCResultKey];
                            data = [[NSData alloc] initWithBase64EncodedString:result options:0];
                        }
                        
                        if (data) {
                            UIImage *contactImage = [UIImage imageWithData:data];
                            if (contactImage) {
                                SetAvatarView(balloonCell, contactImage);
                                [balloonView setNeedsPrepareForDisplay];
                                [balloonView prepareForDisplayIfNeeded];
                                CacheImage(chatItem.userIdentifier, contactImage);
                            }
                        }
                    }];
                }
            } else {
                SetAvatarView(balloonCell, nil);
            }
            
            [balloonView setNeedsPrepareForDisplay];
            [balloonView prepareForDisplayIfNeeded];
        }
    }
}

static inline void MarkAsRead(QRCInlineReplyViewController *controller) {
    NSString *identifier = controller.context[QRCUserIDKey];
    if (identifier != nil) {
        SendClearNotificationsMessage(controller);
        NSDictionary *userInfo = @{QRCMessageIDKey: @(QRCMessageIDMarkAsRead), QRCMessageDataKey: identifier};
        [QRCMessageHandler sendMessageName:QRCMessageNameApplication appIdentifier:currentAppIdentifier userInfo:userInfo];
    }
}

static inline void PlayAudio(CKTranscriptCollectionViewController *controller, CKBalloonView *balloonView) {
    if ([balloonView isKindOfClass:NSClassFromString(@"CKAudioBalloonView")]) {
        
        NSIndexPath *indexPath = [controller indexPathForBalloonView:balloonView];
        CKAudioMediaObject *mediaObject = (CKAudioMediaObject*)[controller.chatItems[indexPath.item] mediaObject];
        
        if (controller.audioController == nil || (controller.audioController && controller.audioController.currentMediaObject && ![controller.audioController.currentMediaObject.transferGUID isEqualToString:mediaObject.transferGUID])) {
            
            if (controller.audioController) {
                [controller.audioController stop];
                controller.audioController.delegate = nil;
                controller.audioController = nil;
            }
            
            CKAudioController *audioController = [[NSClassFromString(@"CKAudioController") alloc] initWithMediaObjects:@[mediaObject]];
            audioController.delegate = controller;
            controller.audioController = audioController;
            [audioController play];
        }
    }
}

static inline void CollectionViewDidScroll(UIScrollView *scrollView) {
    CGFloat scrollViewContentHeight = scrollView.contentSize.height >= scrollView.bounds.size.height ? scrollView.contentSize.height : scrollView.bounds.size.height;
    CGFloat scrollOffsetThreshold = scrollViewContentHeight - scrollView.bounds.size.height + (IS_IPHONE4 ? 50 : 80);
    
    QRCScrollingState previousState = scrollingState;
    
    if (!scrollView.isDragging && scrollingState == QRCScrollingStateTriggered)
        scrollingState = QRCScrollingStateLoading;
    else if(scrollView.contentOffset.y > scrollOffsetThreshold && scrollingState == QRCScrollingStateStopped && scrollView.isDragging)
        scrollingState = QRCScrollingStateTriggered;
    else if(scrollView.contentOffset.y < scrollOffsetThreshold  && scrollingState != QRCScrollingStateStopped)
        scrollingState = QRCScrollingStateStopped;

    if (previousState == QRCScrollingStateTriggered && scrollingState == QRCScrollingStateLoading) {
        [activeReplyController.activityIndicatorView startAnimating];
        QRCDispatchAfter(0.3, ^{ LoadChatMessages(activeReplyController); });
    }
}

static void ShowActivityIndicatorIfNeeded(QRCInlineReplyViewController *controller) {
    QRCDispatchAfter(0.2, ^{
        if (!controller.conversationViewController.chatItems || !controller.conversationViewController.chatItems.count)
            [controller.activityIndicatorView startAnimating];
    });
}

static inline void ViewServiceInit(void) {
    
    [QRCMessageHandler registerMessageName:QRCMessageNameViewService handler:^NSDictionary *(NSDictionary *userInfo) {
        
        QRCMessageID messageId = [userInfo[QRCMessageIDKey] intValue];
        
        if (messageId == QRCMessageIDSelectContact) {
            if (activeReplyController) [activeReplyController selectedContact:userInfo[QRCMessageDataKey]];
        } else if (messageId == QRCMessageIDDeselectContact) {
            if (activeReplyController) [activeReplyController deselectedContact];
        } else if (messageId == QRCMessageIDLoadMessages) {
            if (activeReplyController) {
                if (messagesLoaded) {
                    LoadChatMessages(activeReplyController);
                } else {
                    messagesLoaded = YES;

                    BOOL appIsRunning = [activeReplyController.context[QRCAppIsRunningKey] boolValue];
                    if (!appIsRunning) {
                        NSMutableDictionary *context = activeReplyController.context.mutableCopy;
                        context[QRCAppIsRunningKey] = @(YES);
                        MSHookIvar<NSDictionary*>(activeReplyController, "_context") = context;
                    }
                    
                    if (activeReplyController.view.bounds.size.height != activeReplyController.preferredContentHeight) {
                        [activeReplyController requestPreferredContentHeight:activeReplyController.preferredContentHeight];
                    }
                    [UIView animateWithDuration:0.2 animations:^{
                        CGRect frame = activeReplyController.view.bounds;
                        frame.size.height = activeReplyController.preferredContentHeight;
                        activeReplyController.view.bounds = frame;
                    }];
                    
                    if (appIsRunning) {
                        LoadChatMessages(activeReplyController);
                    } else {
                        [activeReplyController.activityIndicatorView startAnimating];
                        QRCDispatchAfter(IS_IPHONE4 ? 1.0 : 0.6, ^{ LoadChatMessages(activeReplyController); });
                        QRCDispatchAfter(IS_IPHONE4 ? 3.0 : 2.0, ^{ LoadChatMessages(activeReplyController); });
                    }
                }

                return @{QRCResultKey: @(1)};
            }
        } else if (messageId == QRCMessageIDPhotoPicker) {
            [activeReplyController.photoPickerController dissmisPickerView];
        }
        
        return nil;
    }];
    
    customColors = [[NSMutableArray alloc] init];
    prefs = [[NSUserDefaults alloc] initWithSuiteName:AppId];
    [prefs synchronize];
    
    
}

// MARK: - group MobileSMSNotificationHook

%group MobileSMSNotificationHook

// MARK: - CKChatItem

%hook CKChatItem
%new
- (NSString *)userIdentifier {
    return objc_getAssociatedObject(self, @selector(userIdentifier));
}
%new
- (void)setUserIdentifier:(NSString *)value {
    objc_setAssociatedObject(self, @selector(userIdentifier), value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
%end

// MARK: - CKUIBehavior

%hook CKUIBehavior
- (UIColor *)transcriptBackgroundColor {
    if (shouldChangeBalloonColor) {
        return [UIColor clearColor];
    }
    return %orig();
}
- (BOOL)transcriptCanUseOpaqueMask {
    if (shouldChangeBalloonColor) {
        return NO;
    }
    return %orig();
}
- (NSArray *)balloonColorsForColorType:(CKBalloonColor)colorType {
    return (customColors && colorType >= QRCColorType) ? @[customColors[colorType - QRCColorType]] : %orig();
}
- (UIColor *)balloonOverlayColorForColorType:(CKBalloonColor)colorType {
    return colorType >= QRCColorType ? [UIColor colorWithWhite:0 alpha:0.1] : %orig();
}
%end

// MARK: - QRCConversationViewController

static inline void  PresentResendAlert(QRCConversationViewController *controller) {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [alertController addAction:[UIAlertAction actionWithTitle:QRCLocalizedString(@"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [alertController addAction:[UIAlertAction actionWithTitle:QRCLocalizedString(@"Resend Messages") style:UIAlertActionStyleDestructive handler:^(UIAlertAction * action) {
        [QRCMessageHandler sendMessageName:QRCMessageNameApplication appIdentifier:currentAppIdentifier userInfo:@{QRCMessageIDKey: @(QRCMessageIDRetryUnsentMessages), QRCMessageDataKey: activeReplyController.context[QRCUserIDKey]}];
        QRCDispatchAfter(0.2, ^{ LoadChatMessages(activeReplyController); });
    }]];
    [controller presentViewController:alertController animated:YES completion:nil];
}

%subclass QRCConversationViewController: CKTranscriptCollectionViewController
%new
- (void)refreshData {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self reloadData];
    });
}
- (void)configureCell:(CKTranscriptCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    %orig();
    configureCell(self, cell, indexPath);
}
- (BOOL)balloonView:(CKBalloonView *)balloonView canPerformAction:(SEL)action withSender:(id)sender {
    return sel_isEqual(action, @selector(copy:)) ? %orig() : NO;
}
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    %orig();
    CollectionViewDidScroll(scrollView);
}
- (void)touchUpInsideMessageCellFailureButton:(UIButton *)button {
    PresentResendAlert(self);
}
// 9.x
- (void)touchUpInsideCellFailureButton:(UIButton *)button {
    PresentResendAlert(self);
}
%end

// MARK: - QRCInlineReplyViewController

%subclass QRCInlineReplyViewController: CKInlineReplyViewController

%new
- (QRCConversationViewController *)conversationViewController {
    return objc_getAssociatedObject(self, @selector(conversationViewController));
}
%new
- (void)setConversationViewController:(QRCConversationViewController *)value {
    objc_setAssociatedObject(self, @selector(conversationViewController), value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
%new
- (QRCPhotoPickerController *)photoPickerController {
    return objc_getAssociatedObject(self, @selector(photoPickerController));
}
%new
- (void)setPhotoPickerController:(QRCPhotoPickerController *)value {
    objc_setAssociatedObject(self, @selector(photoPickerController), value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
%new
- (UIActivityIndicatorView *)activityIndicatorView {
    return objc_getAssociatedObject(self, @selector(activityIndicatorView));
}
%new
- (void)setActivityIndicatorView:(UIActivityIndicatorView *)value {
    objc_setAssociatedObject(self, @selector(activityIndicatorView), value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
%new
- (void)selectedContact:(NSDictionary *)userInfo {

    canBecomeFirstResponder = YES;
    
    NSMutableDictionary *context = self.context.mutableCopy;
    context[QRCUserIDKey] = userInfo[QRCUserIDKey];
    MSHookIvar<NSDictionary*>(self, "_context") = context;

    self.entryView.hidden = NO;
    [self.entryView.contentView.textView becomeFirstResponder];
    
    [self.view setNeedsLayout];
    
    if (!IsSimpleMode(self)) {
        LoadChatMessages(self);
    } else {
        MarkAsRead(self);
    }
}
%new
- (void)deselectedContact {
    
    NSMutableDictionary *context = self.context.mutableCopy;
    [context removeObjectForKey:QRCUserIDKey];
    MSHookIvar<NSDictionary*>(self, "_context") = context;

    self.entryView.hidden = YES;
    
    if (self.photoPickerController) {
        [self.photoPickerController dissmisPickerView];
    }
    
    if (self.conversationViewController) {
        
        self.conversationViewController.chatItems = [NSMutableArray array];
        [self.conversationViewController refreshData];

        if (self.conversationViewController.audioController) {
            [self.conversationViewController.audioController stop];
            self.conversationViewController.audioController.delegate = nil;
            self.conversationViewController.audioController = nil;
        }
    }
    
    [self.view setNeedsLayout];
    
    messagesLoaded = NO;
    [QRCMessageHandler sendMessageName:QRCMessageNameSpringBoard userInfo:@{QRCMessageIDKey: @(QRCMessageIDLoadMessages), QRCResultKey: @(messagesLoaded)}];
}

%new
- (BOOL)isComposeMode {
    return self.context[QRCComposeModeKey] != nil;
}

- (id)init {
    
    QRCInlineReplyViewController *orig = %orig();
    
    if (orig) {
        
        QRCConversationViewController *conversationViewController = nil;
        if (OS_VERSION >= 9.0f) {
            CKUIBehavior *behavior = [CKUIBehavior sharedBehaviors];
            UIEdgeInsets insets = behavior.minTranscriptMarginInsets;
            CGFloat balloonMaxWidth = [behavior balloonMaxWidthForTranscriptWidth:self.view.bounds.size.width marginInsets:insets shouldShowPhotoButton:YES shouldShowCharacterCount:NO];
            conversationViewController = [[NSClassFromString(@"QRCConversationViewController") alloc] initWithConversation:nil balloonMaxWidth:balloonMaxWidth marginInsets:insets];
        } else {
            conversationViewController = [[NSClassFromString(@"QRCConversationViewController") alloc] init];
        }

        orig.conversationViewController = conversationViewController;
        orig.conversationViewController.view.backgroundColor = [UIColor clearColor];
        [orig addChildViewController:orig.conversationViewController];
        conversationViewController = nil;
        
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:orig action:@selector(handlePan:)];
        pan.delegate = orig;
        [orig.view addGestureRecognizer:pan];
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:orig action:@selector(handleDoubleTap:)];
        tap.numberOfTapsRequired = 2;
        tap.delegate = orig;
        [orig.view addGestureRecognizer:tap];
    }
    
    return orig;
}

- (void)setupView {
    %orig();

    self.view.tag = 1000;
    
    self.entryView.shouldShowPhotoButton = YES;
    
    [self.view addSubview:self.conversationViewController.view];
    
    UIActivityIndicatorView *activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    self.activityIndicatorView = activityIndicatorView;
    self.activityIndicatorView.hidesWhenStopped = YES;
    [self.view addSubview:self.activityIndicatorView];
    activityIndicatorView = nil;
    
    [self.view bringSubviewToFront:self.activityIndicatorView];
    
    if ([prefs boolForKey:QRCReturnAsSendKey])
        self.entryView.contentView.textView.returnKeyType = UIReturnKeySend;
    
    [self.entryView.photoButton addTarget:self action:@selector(photoButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    if ([self isComposeMode]) {
        self.entryView.hidden = YES;
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig();
    
    messagesLoaded = NO;
    
    if ([self isComposeMode]) {
        canBecomeFirstResponder = NO;
    }

    if (self.conversationViewController) {
        if (self.conversationViewController.audioController) {
            [self.conversationViewController.audioController stop];
            self.conversationViewController.audioController.delegate = nil;
            self.conversationViewController.audioController = nil;
        }
        
        [self.activityIndicatorView removeFromSuperview];
        self.activityIndicatorView = nil;
        
        [self.conversationViewController.view removeFromSuperview];
        [self.conversationViewController removeFromParentViewController];
        self.conversationViewController = nil;
    }
    if (self.photoPickerController) {
        [self.photoPickerController.view removeFromSuperview];
        [self.photoPickerController removeFromParentViewController];
        self.photoPickerController = nil;
    }
    
    if ([self isEqual:activeReplyController]) {
        shouldChangeBalloonColor = NO;
        currentAppIdentifier = nil;
        currentProcessName = nil;
        activeReplyController = nil;
        currentColor = nil;
        ClearImageCache();
    }
}

- (void)dismissWithContext:(id)context {
    if ([prefs boolForKey:QRCDismissAfterSendKey] || context != nil) {
        %orig();
    } else {
        if (!IsSimpleMode(self)) QRCDispatchAfter(0.2, ^{ LoadChatMessages(activeReplyController); });
    }
}

- (void)interactiveNotificationDidAppear {
    
    if (!activeReplyController) {
        activeReplyController = nil;
        activeReplyController = self;
        currentAppIdentifier = nil;
        currentAppIdentifier = self.context[QRCAppIdentifierKey];
        currentProcessName = nil;
        currentProcessName = self.context[QRCProcessNameKey];
        currentColor = nil;
        currentColor = self.context[QRCColorKey];
    }

    %orig();
    
    NSString *identifier = self.context[QRCUserIDKey];
    
    if (identifier != nil) {
        
        self.entryView.hidden = NO;
        self.conversationViewController.view.hidden = NO;
        
        if (![self isComposeMode]) {
            BOOL appIsRunning = [self.context[QRCAppIsRunningKey] boolValue];
            if (!IsSimpleMode(self)) {
                if (appIsRunning) {
                    LoadChatMessages(self);
                    ShowActivityIndicatorIfNeeded(self);
                    QRCDispatchAfter(0.6, ^{
                        if (!self.conversationViewController.chatItems || !self.conversationViewController.chatItems.count) LoadChatMessages(self);
                    });
                } else {
                    [self.activityIndicatorView startAnimating];
                    QRCDispatchAfter(IS_IPHONE4 ? 1.0 : 0.6, ^{ LoadChatMessages(self); });
                    QRCDispatchAfter(IS_IPHONE4 ? 3.0 : 2.0, ^{ LoadChatMessages(self); });
                }
            } else {
                if (appIsRunning) {
                    MarkAsRead(self);
                } else {
                    QRCDispatchAfter(IS_IPHONE4 ? 1.0 : 0.6, ^{ MarkAsRead(self); });
                    QRCDispatchAfter(IS_IPHONE4 ? 3.0 : 2.0, ^{ MarkAsRead(self); });
                }
            }
        }
    } else {
        
        self.entryView.hidden = YES;
        self.conversationViewController.view.hidden = YES;
    }
}

- (BOOL)shouldShowKeyboard {
    if ([self isComposeMode] && !canBecomeFirstResponder) {
        return NO;
    } else {
        return %orig();
    }
}

- (CGFloat)maximumHeight {
    CGFloat orig = %orig();
    
    if (orig > 0) {
        CGFloat height = [UIScreen mainScreen].bounds.size.height;
        CGSize keyboardSize = [NSClassFromString(@"UIKeyboard") defaultSizeForInterfaceOrientation:[UIApplication sharedApplication].statusBarOrientation];
        if (orig > height - keyboardSize.height - 44) orig = height - keyboardSize.height - 44;
    }
    
    return orig;
}

- (CGFloat)preferredContentHeight {
    
    CGFloat orig = %orig();
    
    if (IsSimpleMode(self)) {
        if (self.photoPickerController.presented) {
            return self.photoPickerController.pickerViewHeight > orig ? self.photoPickerController.pickerViewHeight : orig;
        } else {
            if (orig < 52.0) orig = 52.0;
            return orig;
        }
    }

    orig = self.maximumHeight ? self.maximumHeight : orig;
    if (orig <= 52.0) {
        if (orig <= 0) {
            CGFloat height = [UIScreen mainScreen].bounds.size.height;
            CGSize keyboardSize = [NSClassFromString(@"UIKeyboard") defaultSizeForInterfaceOrientation:[UIApplication sharedApplication].statusBarOrientation];
            orig = height - keyboardSize.height - 44;
        } else orig = orig * 2;
    }
    
    return orig;
}

- (void)viewDidLayoutSubviews {
    %orig();

    CGFloat contentHeight = self.preferredContentHeight;
    if (self.view.bounds.size.height != contentHeight) {
        [self requestPreferredContentHeight:contentHeight];
    }
    
    if (OS_VERSION >= 9.0f) {
        CGRect bounds = self.view.frame;
        bounds.origin.y = 0.0f;
        bounds.size.height = contentHeight;
        self.view.frame = bounds;
    }

    if (IsSimpleMode(self)) return;
    
    CGSize size = self.view.bounds.size;

    CGFloat entryHeight = MIN([self.entryView sizeThatFits:size].height, size.height);

    CGFloat conversationHeight = size.height - entryHeight;
    self.conversationViewController.view.frame = CGRectMake(0, 0, size.width, conversationHeight);

    
    CGRect frame = self.activityIndicatorView.frame;
    frame.origin.x = (size.width - frame.size.width) / 2;
    frame.origin.y = (size.height - entryHeight - frame.size.height) / 2;
    self.activityIndicatorView.frame = frame;

    self.entryView.frame = CGRectMake(0.0, size.height - entryHeight, size.width, entryHeight);
    
    if (self.photoPickerController) {
        CGRect frame = self.photoPickerController.view.frame;
        frame.origin.y = size.height - frame.size.height;
        self.photoPickerController.view.frame = frame;
    }
    
    if (!self.conversationViewController.collectionView.__ck_isScrolledToBottom) {
        [self.conversationViewController.collectionView __ck_scrollToBottom:NO];
    }
}

- (void)messageEntryViewDidChange:(CKMessageEntryView *)entryView {
    %orig();
    [self.view setNeedsLayout];
}

- (void)sendMessage {
    if (!self.entryView.sendButton.enabled) return;
    
    self.entryView.sendButton.enabled = NO;
    
    CKComposition *composition = self.entryView.composition;
    
    NSString *text = composition.text.string;
    text = [text stringByReplacingOccurrencesOfString:@"\n\ufffc\n" withString:@"\n"];
    text = [text stringByReplacingOccurrencesOfString:@"\n\ufffc" withString:@""];
    text = [text stringByReplacingOccurrencesOfString:@"\ufffc\n" withString:@""];
    text = [text stringByReplacingOccurrencesOfString:@"\ufffc" withString:@""];
    if ([text isEqualToString:@"\n"]) text = @"";
    
    NSMutableArray *images = [NSMutableArray array];
    for (CKMediaObject *mediaObject in composition.mediaObjects) {
        [images addObject:[mediaObject.data base64EncodedStringWithOptions:0]];
    }
    
    NSDictionary *userInfo = @{QRCMessageIDKey: @(QRCMessageIDSendMessage), QRCMessageDataKey: @{QRCUserIDKey: self.context[QRCUserIDKey], QRCContentKey: text, QRCImagesKey: images}};
    [QRCMessageHandler sendMessageName:QRCMessageNameApplication appIdentifier:currentAppIdentifier userInfo:userInfo];
    
    [self.entryView.contentView.textView setCompositionText:nil];
    [self.entryView.contentView.textView.mediaObjects removeAllObjects];
}

%new
- (void)photoButtonTapped:(UIButton *)button {
    
    if (self.photoPickerController == nil) {
        
        QRCPhotoPickerController *photoPickerController = [[QRCPhotoPickerController alloc] initWithFrame:self.view.frame];
        self.photoPickerController = photoPickerController;
        photoPickerController = nil;
        [self addChildViewController:self.photoPickerController];
        [self.view addSubview:self.photoPickerController.view];
        
        __weak QRCInlineReplyViewController *weakSelf = self;
        self.photoPickerController.selectedHandler = ^(UIImage *image) {
            NSMutableArray *mediaObjects = [NSMutableArray array];
            CKMediaObject *mediaObject = [[NSClassFromString(@"CKMediaObjectManager") sharedInstance] mediaObjectWithData:UIImageJPEGRepresentation(image, 0.8) UTIType:(__bridge NSString *)kUTTypeJPEG filename:@"image.jpg" transcoderUserInfo:@{IMFileTransferAVTranscodeOptionAssetURI: @"image.jpg"}];
            if (mediaObject) {
                [mediaObjects addObject:mediaObject];
                CKComposition *photosComposition = [CKComposition photoPickerCompositionWithMediaObjects:mediaObjects];
                weakSelf.entryView.composition = [weakSelf.entryView.composition compositionByAppendingComposition:photosComposition];
                
                [weakSelf.photoPickerController dissmisPickerView];
            }
        };
    }
    
    [self.photoPickerController presentPickerView];
}

%new
- (void)handlePan:(UIPanGestureRecognizer *)recognizer {
    CGPoint velocity = [recognizer velocityInView:recognizer.view];
    CGPoint location = [(UIPanGestureRecognizer *)recognizer locationInView:recognizer.view];
    if (recognizer.enabled && recognizer.state == UIGestureRecognizerStateChanged) {
        if (location.y > recognizer.view.frame.size.height + 30.0f && velocity.y > 200.0f) {
            recognizer.enabled = NO;
            [self dismissWithContext:@{}];
            recognizer.enabled = YES;
        }
    }
}
%new
- (void)handleDoubleTap:(UITapGestureRecognizer *)recognizer {
    NSMutableDictionary *context = self.context.mutableCopy;
    context[QRCComposeModeKey] = [NSNumber numberWithBool:YES];
    MSHookIvar<NSDictionary*>(self, "_context") = context;
    [QRCMessageHandler sendMessageName:QRCMessageNameSpringBoard userInfo:@{QRCMessageIDKey : @(QRCMessageIDSwitchToSelectContact)}];
}

%new
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer shouldReceiveTouch:(UITouch *)touch {
    if ([recognizer isKindOfClass:UITapGestureRecognizer.class] && [recognizer.view isEqual:self.view]) {
        return ([touch.view isKindOfClass:NSClassFromString(@"CKBalloonView")] || [touch locationInView:self.view].y > self.view.frame.size.height - 52) ? NO : YES;
    } else if ([recognizer isKindOfClass:UIPanGestureRecognizer.class] && [recognizer.view isEqual:self.view]) {
        return ([touch.view isKindOfClass:NSClassFromString(@"UIButton")]) ? NO: YES;
    }
    return NO;
}
%new
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)recognizer {
    if ([recognizer isKindOfClass:UIPanGestureRecognizer.class] && [recognizer.view isEqual:self.view]) {
        CGPoint translation = [(UIPanGestureRecognizer *)recognizer translationInView:recognizer.view];
        return sqrt(translation.y * translation.y) / sqrt(translation.x * translation.x) > 1 && translation.y > 0;
    } else if ([recognizer isKindOfClass:UITapGestureRecognizer.class] && [recognizer.view isEqual:self.view]) {
        return YES;
    }
    return NO;
}
%new
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherRecognizer {
    if (([recognizer isKindOfClass:UIPanGestureRecognizer.class] && [recognizer.view isEqual:self.view])
        || ([recognizer isKindOfClass:UITapGestureRecognizer.class] && [recognizer.view isEqual:self.view])) {
        return YES;
    }
    return NO;
}
%end

// MARK: - CKMessageEntryView
%hook CKMessageEntryView
%new
- (void)qrc_handleSwipe:(UISwipeGestureRecognizer *)recognizer {
    if (self.composition.hasContent) {
        [activeReplyController sendMessage];
        if ([prefs boolForKey:QRCDismissAfterSendKey]) {
            if (!IsSimpleMode(activeReplyController)) QRCDispatchAfter(0.2, ^{ LoadChatMessages(activeReplyController); });
        } else {
            [activeReplyController dismissWithContext:@{}];
        }
    }
}
%new
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}
// < 9.0
- (id)initWithFrame:(CGRect)frame shouldShowSendButton:(BOOL)sendButton shouldShowSubject:(BOOL)subject shouldShowPhotoButton:(BOOL)photoButton shouldShowCharacterCount:(BOOL)characterCount {
    photoButton = YES;
    return %orig();
}
// 9.x
- (id)initWithFrame:(CGRect)arg1 marginInsets:(UIEdgeInsets)arg2 shouldShowSendButton:(BOOL)sendButton shouldShowSubject:(BOOL)subject shouldShowPhotoButton:(BOOL)photoButton shouldShowCharacterCount:(BOOL)characterCount {
    photoButton = YES;
    return %orig();
}
- (void)willMoveToSuperview:(UIView *)superview {
    if (superview) {
        if (superview.tag > 0) {
            if (!self.sendButton.gestureRecognizers) {
                UISwipeGestureRecognizer *swipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(qrc_handleSwipe:)];
                swipe.delegate = self;
                swipe.direction = UISwipeGestureRecognizerDirectionDown;
                [self.sendButton addGestureRecognizer:swipe];
                swipe = nil;
            }
        } else {
            self.shouldShowPhotoButton = NO;
        }
    }
    
    %orig();
}
- (void)setShouldShowPhotoButton:(BOOL)show {
    %orig();
    self.photoButton.hidden = !show;
    [self setNeedsLayout];
}
- (void)updateEntryView {
    %orig();
    if (self.conversation.chat == nil) {
        self.sendButton.enabled = self.composition.hasContent;
        self.photoButton.enabled = YES;
    }
}
%end

// MARK: - CKMessageEntryContentView
%hook CKMessageEntryContentView
%new
- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    if (textView.returnKeyType == UIReturnKeySend && [text isEqualToString:@"\n"]) {
        if (activeReplyController.entryView.composition.hasContent) {
            [activeReplyController.entryView touchUpInsideSendButton:activeReplyController.entryView.sendButton];
        }
        return NO;
    }
    return YES;
}
%end

%hook CKTranscriptCollectionViewController
- (void)balloonViewTapped:(CKBalloonView *)balloonView {
    %orig();
    PlayAudio(self, balloonView);
}
- (void)audioController:(id)arg1 mediaObjectDidFinishPlaying:(id)arg2{
    %orig();
    self.audioController.delegate = nil;
    self.audioController = nil;
}
%end

%hook CKAttachmentMessagePartChatItem
- (Class)balloonViewClass {
    if (self.mediaObject && [self.mediaObject isKindOfClass:NSClassFromString(@"CKAudioMediaObject")]) {
        return NSClassFromString(@"CKAudioBalloonView");
    }

    return %orig();
}
%end

%hook NSDistributedNotificationCenter
- (void)removeObserver:(id)notificationObserver name:(NSString *)notificationName object:(NSString *)notificationSender {
    if (![notificationName isEqualToString:QRCMessageNameViewService]) {
        %orig();
    }
}
%end

%end

// MARK: - AssertiondHook

@interface BKProcessAssertionServer : NSObject
- (BOOL)_queue_assertionAllowedForProcess:(id)arg1 withConnection:(id)arg2 fromPID:(int)arg3 reason:(unsigned)arg4 outServiceHost:(id*)arg5;
@end

%group AssertiondHook
%hook BKProcessAssertionServer
- (BOOL)_queue_assertionAllowedForProcess:(id)process withConnection:(id)arg2 fromPID:(int)pid reason:(unsigned)arg4 outServiceHost:(id*)arg5  {
    BOOL orig = %orig();
    if (pid == PIDForProcessNamed(@"SpringBoard")) {
        return YES;
    }
    return orig;
}
%end %end

@interface BSAuditToken : NSObject
+ (id)tokenFromAuditToken:(void *)auditToken;
- (int)pid;
- (id)bundleID;
@end

static BOOL (*orignal_BSAuditTokenTaskHasEntitlement)(void * auditToken, NSString *entitlement);
static inline BOOL replaced_BSAuditTokenTaskHasEntitlement(void * auditToken, NSString *entitlement) {
    if ([entitlement isEqualToString:@"com.apple.multitasking.unlimitedassertions"]) {
        BSAuditToken *token = (BSAuditToken*)[objc_getClass("BSAuditToken") tokenFromAuditToken:auditToken];
        if (token.pid == PIDForProcessNamed(@"SpringBoard")) {
            return YES;
        }
    }
    return orignal_BSAuditTokenTaskHasEntitlement(auditToken, entitlement);
}

// MARK: - ctor

%ctor
{
    @autoreleasepool
    {
        NSString *processName = [NSProcessInfo processInfo].processName;
        if ([processName isEqualToString:AssertiondProcessName])
        {
            %init(AssertiondHook);
            MSHookFunction(((int *)MSFindSymbol(NULL, "_BSAuditTokenTaskHasEntitlement")), (int *)replaced_BSAuditTokenTaskHasEntitlement, (void **)&orignal_BSAuditTokenTaskHasEntitlement);
        } else {
            NSString *identifier = [[NSBundle mainBundle] bundleIdentifier];
            if ([identifier isEqualToString:SpringBoardIdentifier]) {
                %init(SpringBoardHook);
                SpringBoardInit();
            } else if ([identifier isEqualToString:MessagesNotificationIdentifier]) {
                %init(MobileSMSNotificationHook);
                ViewServiceInit();
            }
        }
    }
}