#include <unistd.h>
#include <sys/sysctl.h>
#include <pwd.h>

#import "libqrc.h"
#import "headers.h"
#import "Helper.h"

static inline void ExecuteOnMainThread(void (^block)(void)) {
    if (![NSThread isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), block);
    } else {
        block();
    }
}

void QRCDispatchAfter(CGFloat delay, void (^block)(void)) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void) {
        block();
    });
}

void TerminateApp(NSString *appId) {
    BKSTerminateApplicationForReasonAndReportWithDescription((__bridge CFStringRef)appId, 1, 0, NULL);
}

BOOL AppIsRunning(NSString *processName) {
    return (PIDForProcessNamed(processName) > 0);
}

void LaunchAppInBackground(NSString *appIdentifier, NSString *processName) {
    if (!AppIsRunning(processName)) {
        ExecuteOnMainThread(^{
            [[UIApplication sharedApplication] launchApplicationWithIdentifier:appIdentifier suspended:YES];
        });
    }
}

// MARK: - ImageCache

static NSMutableDictionary *_imageCache = nil;

void ClearImageCache(void) {
    if (_imageCache) {
        [_imageCache removeAllObjects];
        _imageCache = nil;
    }
}

void CacheImage(NSString *key, UIImage *image) {
    if (!_imageCache) _imageCache = [[NSMutableDictionary alloc] init];
    [_imageCache setObject:image forKey:key];
}

id CachedImage(NSString *key) {
    if (!_imageCache) _imageCache = [[NSMutableDictionary alloc] init];
    return [_imageCache objectForKey:key];
}

// MARK: - PIDForProcessNamed

int PIDForProcessNamed(NSString *name)
{
    int pid = 0;
    
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
    size_t miblen = 4;
    
    size_t size;
    int st = sysctl(mib, (u_int)miblen, NULL, &size, NULL, 0);
    
    struct kinfo_proc * process = NULL;
    struct kinfo_proc * newprocess = NULL;
    
    do {
        size += size / 10;
        newprocess = (struct kinfo_proc *)realloc(process, size);
        
        if (!newprocess) {
            if (process) {
                free(process);
            }
            return 0;
        }
        
        process = newprocess;
        st = sysctl(mib, (u_int)miblen, process, &size, NULL, 0);
    } while (st == -1 && errno == ENOMEM);
    
    if (st == 0) {
        if (size % sizeof(struct kinfo_proc) == 0) {
            int nprocess = (int)(size / sizeof(struct kinfo_proc));
            
            if (nprocess) {
                for (int i = nprocess - 1; i >= 0; i--) {
                    NSString *processName = [[NSString alloc] initWithFormat:@"%s", process[i].kp_proc.p_comm];
                    
                    if ([processName isEqualToString:name]) {
                        pid = process[i].kp_proc.p_pid;
                    }
                }
                
                free(process);
            }
        }
    }
    
    return pid;
}

#define kBundlePath @"/Library/PreferenceBundles/QRCSettings.bundle"
NSString * QRCLocalizedString(NSString *key) {
    static NSBundle *bundle;
    if (!bundle) bundle = [[NSBundle alloc] initWithPath:kBundlePath];
    return [bundle localizedStringForKey:key value:key table:nil];
}
