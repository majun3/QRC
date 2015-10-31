#import <UIKit/UIKit.h>

#define OS_VERSION  [[[UIDevice currentDevice] systemVersion] floatValue]
#define IS_RETINA   ([[UIScreen mainScreen] scale] >= 2.0f)
#define IS_IPAD     (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
#define IS_IPHONE   (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
#define IS_IPHONE4  (IS_IPHONE && [[UIScreen mainScreen] bounds].size.height == 480.0f)
#define IS_IPHONE5  (IS_IPHONE && [[UIScreen mainScreen] bounds].size.height == 568.0f)
#define IS_IPHONE6  (IS_IPHONE && [[UIScreen mainScreen] bounds].size.height == 667.0f)
#define IS_IPHONE6P (IS_IPHONE && ([[UIScreen mainScreen] bounds].size.height == 736.0f || [[UIScreen mainScreen] bounds].size.width == 736.0f))

#ifdef __cplusplus
extern "C" {
#endif
    NSString * SBSCopyLocalizedApplicationNameForDisplayIdentifier(NSString *identifier);
    void BKSTerminateApplicationForReasonAndReportWithDescription(CFStringRef appId, int unknown0, int unknown1, CFStringRef description);
    void TerminateApp(NSString *appId);
    
    BOOL AppIsRunning(NSString *processName);
    void LaunchAppInBackground(NSString *appIdentifier, NSString *processName);
    
    void ClearImageCache(void);
    void CacheImage(NSString *key, UIImage *image);
    id CachedImage(NSString *key);
    
    int PIDForProcessNamed(NSString *name);
#ifdef __cplusplus
}
#endif