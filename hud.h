#import <UIKit/UIKit.h>

@interface UIProgressHUD : UIView
- (id)initWithFrame:(CGRect)frame;
- (void)showInView:(UIView*)view;
- (void)setShowsText:(BOOL)flag;
- (void)hide;
@end

@interface QRCWindow : UIWindow
- (BOOL)_shouldCreateContextAsSecure;
@end


#ifdef __cplusplus
extern "C" {
#endif
    BOOL IsShowHUD(void);
    void ShowHUD(void);
    void HideHUD(void);
#ifdef __cplusplus
}
#endif