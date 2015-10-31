#import "PhotoPickerController.h"
#import <Photos/Photos.h>
#import "libqrc.h"

// MARK: - QRCPhotoPickerCell

@implementation QRCPhotoPickerCell

- (instancetype) initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.contentView.frame = self.bounds;
        self.backgroundColor = [UIColor clearColor];
        
        _imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0, 0.0, frame.size.width, frame.size.height)];
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.clipsToBounds = YES;
        _imageView.userInteractionEnabled = YES;
        [self.contentView addSubview:_imageView];
    }
    
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.imageView.frame = CGRectMake(0.0, 0.0, self.frame.size.width, self.frame.size.height);
}

@end


// MARK: - QRCPhotoPickerController

static NSUInteger const kPhotoLimit = 20;
static NSString *kPhotoPickerCell = @"PhotoPickerCell";

@interface QRCPhotoPickerController()<UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate> {
    CGFloat _pickerViewHeight;
}
@property (nonatomic, strong) UIView *pickerView;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UIButton *cancleButton;
@property (nonatomic, strong) PHFetchResult *assets;
@property (nonatomic, strong) PHCachingImageManager *imageManager;
@end

@implementation QRCPhotoPickerController

+ (CGFloat)pickerViewHeight {
    return 140;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super init];
    
    if (self) {
        self.view.frame = frame;
        self.view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.3];
        
        _pickerViewHeight = 140;
        self.imageManager = [[PHCachingImageManager alloc] init];
        [self.imageManager stopCachingImagesForAllAssets];
        
        [self refreshData];
    }
    
    return self;
}

// MARK: - UIViewController

- (void)loadView {
    [super loadView];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.pickerView = [[UIView alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height, self.view.frame.size.width, _pickerViewHeight)];
    [self.view addSubview:self.pickerView];
    
    _UIBackdropViewSettings *settings = [NSClassFromString(@"_UIBackdropViewSettingsDark") settingsForStyle:2030];
    _UIBackdropView *backdropView = [[NSClassFromString(@"_UIBackdropView") alloc] initWithFrame:self.pickerView.frame autosizesToFitSuperview:YES settings:settings];
    [self.pickerView addSubview:backdropView];

    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 140) collectionViewLayout:layout];
    self.collectionView.backgroundColor = [UIColor clearColor];
    self.collectionView.showsHorizontalScrollIndicator = NO;
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    [self.collectionView registerClass:QRCPhotoPickerCell.class forCellWithReuseIdentifier:kPhotoPickerCell];
    [self.pickerView addSubview:self.collectionView];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dissmisPickerView)];
    tap.delegate = self;
    [self.view addGestureRecognizer:tap];
    
    self.view.hidden = YES;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self presentPickerView];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    self.pickerView.frame = CGRectMake(0, self.view.frame.size.height - _pickerViewHeight, self.view.frame.size.width, _pickerViewHeight);
    self.collectionView.frame = CGRectMake(0, 0, self.view.frame.size.width, 140);
}

// MARK: - Action

- (void)refreshData {
    PHFetchOptions *options = [[PHFetchOptions alloc] init];
    options.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
    self.assets = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:options];
}

- (void)presentPickerView {
    [self.collectionView reloadData];
    
    self.presented = YES;
    [self.view.superview setNeedsLayout];
    [QRCMessageHandler sendMessageName:QRCMessageNameSpringBoard userInfo:@{QRCMessageIDKey: @(QRCMessageIDPhotoPicker), QRCResultKey: [NSNumber numberWithBool:self.presented]}];
    
    self.view.hidden = NO;
    [self.view.superview bringSubviewToFront:self.view];
    
    CGRect frame = self.pickerView.frame;
    frame.origin.y = self.view.frame.size.height;
    self.pickerView.frame = frame;
    
    [UIView animateWithDuration:0.3 animations:^{
        CGRect frame = self.pickerView.frame;
        frame.origin.y = self.view.frame.size.height - _pickerViewHeight;
        self.pickerView.frame = frame;
    }];
}

- (void)dissmisPickerView {
    self.presented = NO;
    [QRCMessageHandler sendMessageName:QRCMessageNameSpringBoard userInfo:@{QRCMessageIDKey: @(QRCMessageIDPhotoPicker), QRCResultKey: [NSNumber numberWithBool:self.presented]}];
    
    [UIView animateWithDuration:0.2 animations:^{
        CGRect frame = self.pickerView.frame;
        frame.origin.y = self.view.frame.size.height;
        self.pickerView.frame = frame;
    } completion:^(BOOL finished) {
        [self.collectionView scrollRectToVisible:CGRectMake(0, 0, 10, self.collectionView.frame.size.height) animated:NO];
        self.view.hidden = YES;
        [self.view.superview setNeedsLayout];
    }];
}

// MARK: - UICollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.assets.count > kPhotoLimit ? kPhotoLimit : self.assets.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    QRCPhotoPickerCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:kPhotoPickerCell forIndexPath:indexPath];

    NSInteger currentTag = cell.tag + 1;
    cell.tag = currentTag;
    
    PHAsset *asset = self.assets[indexPath.item];
    
    CGFloat scale = [UIScreen mainScreen].scale;
    CGSize targetSize = CGSizeMake(CGRectGetWidth(cell.imageView.bounds) * scale, CGRectGetHeight(cell.imageView.bounds) * scale);

    [self.imageManager requestImageForAsset:asset targetSize:targetSize contentMode:PHImageContentModeAspectFit options:nil
        resultHandler:^(UIImage *result, NSDictionary *info) {
            if (result && ![info[@"PHImageResultIsDegradedKey"] boolValue] && cell.tag == currentTag) {
                cell.imageView.image = result;
            }
    }];
    
    return cell;
}

// MARK: - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    PHAsset *asset = self.assets[indexPath.item];

    CGFloat scale = [UIScreen mainScreen].scale;
    CGFloat width = CGRectGetWidth(self.view.frame);
    CGFloat height = width * asset.pixelHeight / asset.pixelWidth;
    CGSize targetSize = CGSizeMake(width * scale, height * scale);
    
    [[PHImageManager defaultManager] requestImageForAsset:asset targetSize:targetSize contentMode:PHImageContentModeAspectFit options:nil resultHandler:^(UIImage *result, NSDictionary *info) {
        if (result && ![info[@"PHImageResultIsDegradedKey"] boolValue]) {
            if (self.selectedHandler) {
                self.selectedHandler(result);
            }
        } 
    }];
}

// MARK: - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    PHAsset *asset = self.assets[indexPath.item];
    CGFloat height = 130;
    CGFloat width = (NSUInteger)(height * asset.pixelWidth / asset.pixelHeight);
    if (width > 2.5 * height) width = 2.5 * height;
    
    return CGSizeMake(width, height);
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
    return UIEdgeInsetsMake(5.0, 5.0, 5.0, 5.0);
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    return 5.0;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    return 5.0;
}

// MARK: - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if (![touch.view isEqual:gestureRecognizer.view]) return NO;
    else return YES;
}

@end
