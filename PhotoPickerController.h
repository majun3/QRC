
#import <UIKit/UIKit.h>

// _UIBackdropView

@interface _UIBackdropViewSettings : NSObject
@property(copy, nonatomic) NSString *blurQuality;
@property(nonatomic) CGFloat blurRadius;
@property(retain, nonatomic) UIColor *colorTint;
@property(nonatomic) CGFloat colorTintAlpha;
@property(nonatomic) CGFloat grayscaleTintAlpha;
+ (id)settingsForStyle:(NSInteger)arg1;
@end

@interface _UIBackdropView : UIView
- (id)initWithFrame:(struct CGRect)arg1 autosizesToFitSuperview:(BOOL)arg2 settings:(_UIBackdropViewSettings*)arg3;
@end

// QRCPhotoPicker

@interface QRCPhotoPickerCell : UICollectionViewCell
@property (nonatomic, readonly) UIImageView *imageView;
@end

@interface QRCPhotoPickerController : UIViewController

@property(nonatomic, assign) BOOL presented;
@property(nonatomic, readonly) CGFloat pickerViewHeight;
@property(nonatomic, copy) void (^ selectedHandler)(UIImage *image);

+ (CGFloat)pickerViewHeight;
- (instancetype)initWithFrame:(CGRect)frame;
- (void)presentPickerView;
- (void)dissmisPickerView;

@end

