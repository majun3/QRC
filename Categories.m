#import "libqrc.h"

@implementation UIImage(QRC)

- (UIImage *)qrc_scaleToSize:(CGSize)size {
    
    if ([UIScreen mainScreen].scale > 0.0f) {
        UIGraphicsBeginImageContextWithOptions(size, NO, [UIScreen mainScreen].scale);
    } else {
        UIGraphicsBeginImageContext(size);
    }
    
    [self drawInRect:CGRectMake(0.0, 0.0, size.width, size.height)];
    
    UIImage *scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return scaledImage;
}

- (UIImage *)qrc_applyCornerRadius:(CGFloat)cornerRadius {
    
    CGFloat w = self.size.width;
    CGFloat h = self.size.height;
    
    CGFloat scale = [UIScreen mainScreen].scale;
    
    if (cornerRadius < 0) cornerRadius = 0;
    else if (cornerRadius > MIN(w, h)) cornerRadius = MIN(w, h) / 2.;
    
    UIImage *image = nil;
    CGRect imageFrame = CGRectMake(0., 0., w, h);
    
    UIGraphicsBeginImageContextWithOptions(self.size, NO, scale);
    
    [[UIBezierPath bezierPathWithRoundedRect:imageFrame cornerRadius:cornerRadius] addClip];
    
    [self drawInRect:imageFrame];
    
    image = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return image;
}

@end

@implementation UIImageView(QRC)
- (void)setQrc_fadeImage:(UIImage *)image {
    CATransition *transtion = [CATransition animation];
    transtion.duration = 0.2;
    [transtion setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
    [transtion setType:kCATransitionFade];
    [self.layer addAnimation:transtion forKey:kCATransitionFade];
    self.image = image;
}
@end
