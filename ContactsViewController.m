
#import "headers.h"
#import "Helper.h"
#import "ContactsViewController.h"
#import "libqrc.h"

extern NSUserDefaults *prefs;
extern BOOL needRefreshContacts;
extern NSString *currentAppIdentifier;
extern NSString *currentProcessName;

@interface QRCContactCell() {
    UILabel *_badgeLabel;
}
@end

@implementation QRCContactCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier];
    
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.selectedBackgroundView = [[UIView alloc] initWithFrame:CGRectZero];
        self.selectedBackgroundView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.1];
        self.textLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
        self.detailTextLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.3];

        _timeLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.contentView.frame.size.width - 100.0, 0.0, 80.0, 30.0)];
        _timeLabel.backgroundColor = [UIColor clearColor];
        _timeLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.4];
        _timeLabel.font = [UIFont systemFontOfSize:12.0];
        _timeLabel.textAlignment = NSTextAlignmentRight;
        [self.contentView addSubview:_timeLabel];
        
        _badgeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0, 0.0, 12, 12)];
        _badgeLabel.backgroundColor = [UIColor redColor];
        _badgeLabel.textColor = [UIColor whiteColor];
        _badgeLabel.highlightedTextColor = [UIColor clearColor];
        _badgeLabel.font = [UIFont systemFontOfSize:8.0];
        _badgeLabel.textAlignment = NSTextAlignmentCenter;
        _badgeLabel.layer.masksToBounds = YES;
        _badgeLabel.layer.cornerRadius = _badgeLabel.frame.size.width / 2;
        _badgeLabel.hidden = YES;
        [self addSubview:_badgeLabel];
    }
    
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    _timeLabel.frame = CGRectMake(self.contentView.frame.size.width - 100.0, 0.0, 80.0, 30.0);
    _badgeLabel.frame = CGRectMake(CGRectGetMaxX(self.imageView.frame) - _badgeLabel.frame.size.width / 2 - 2, CGRectGetMinY(self.imageView.frame) - _badgeLabel.frame.size.height / 2 + 2, _badgeLabel.frame.size.width, _badgeLabel.frame.size.height);
}

- (void)setBadgeNumber:(NSUInteger)badgeNumber {
    _badgeNumber = badgeNumber;
    if (badgeNumber > 0) {
        _badgeLabel.hidden = NO;
        _badgeLabel.text = badgeNumber > 99 ? @"99+" : [NSString stringWithFormat:@"%lu", (unsigned long)badgeNumber];
        
        CGRect frame = _badgeLabel.frame;
        if (badgeNumber > 99) frame.size.width = 18;
        _badgeLabel.frame = frame;
    } else {
        _badgeLabel.hidden = YES;
    }
}

@end

@interface QRCContactsViewController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate> {
    UIImage *_defaultAvatar;
}
@end

static NSString * const reuseIdentifier = @"QRCContactCell";

@implementation QRCContactsViewController

- (instancetype)initWithFrame:(CGRect)frame {
    
    self = [super init];
    
    if (self) {
        self.view.frame = frame;
        self.view.backgroundColor = [UIColor colorWithWhite:1.0 alpha:1.0 / 255.0];
        
        _contacts = [[NSMutableArray alloc] init];

        _defaultAvatar = [[CKAddressBook transcriptContactImageOfDiameter:[CKUIBehavior sharedBehaviors].transcriptContactImageDiameter forRecordID:(ABRecordID)0] qrc_scaleToSize:QRCAvatarSize];
        
        _appeared = NO;
    }
    
    return self;
}

// MARK: - ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.clipsToBounds = YES;
    
    _textField = [[UITextField alloc] initWithFrame:CGRectMake(55.0f, 0.0, self.view.frame.size.width - 75.0, 44.0)];
    _textField.backgroundColor = [UIColor clearColor];
    _textField.textColor = [UIColor whiteColor];
    _textField.font = [UIFont systemFontOfSize:18.0];
    _textField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:QRCLocalizedString(@"Select or enter contact ...") attributes:@{NSForegroundColorAttributeName:[[UIColor whiteColor] colorWithAlphaComponent:0.2]}];
    _textField.tintColor = [[UIColor whiteColor] colorWithAlphaComponent:0.4];
    _textField.keyboardAppearance = UIKeyboardAppearanceDark;
    _textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    _textField.delegate = self;
    [_textField addTarget:self action:@selector(textFieldEditingChanged:) forControlEvents:UIControlEventEditingChanged];
    [self.view addSubview:_textField];
    
    _avatarImageView = [[UIImageView alloc] initWithImage:_defaultAvatar];
    _avatarImageView.frame = CGRectMake(15.0, 8.0, 28.0, 28.0);
    _avatarImageView.contentMode = UIViewContentModeScaleAspectFit;
    _avatarImageView.hidden = YES;
    [self.view addSubview:_avatarImageView];
    
    _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0.0, CGRectGetMaxY(_textField.frame), self.view.frame.size.width, 0.0) style:UITableViewStylePlain];
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.separatorColor = [[UIColor whiteColor] colorWithAlphaComponent:0.1];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.hidden = YES;
    [self.view addSubview:_tableView];
    
    _tableView.rowHeight = 44.0f;
    [_tableView registerClass:QRCContactCell.class forCellReuseIdentifier:reuseIdentifier];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    pan.delegate = self;
    [self.view addGestureRecognizer:pan];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    _appeared = YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    _textField.frame = CGRectMake(55.0f, 0.0, self.view.frame.size.width - 75.0, 44.0);

    _avatarImageView.frame = CGRectMake(13.5, 8.0, 28.0, 28.0);

    self.tableView.frame = CGRectMake(0.0, CGRectGetMaxY(_textField.frame), self.view.frame.size.width, self.tableView.frame.size.height);
}

- (void)selectContact:(NSDictionary *)userInfo {
    self.view.backgroundColor = [UIColor clearColor];
    [QRCMessageHandler sendMessageName:QRCMessageNameViewService userInfo:@{QRCMessageIDKey: @(QRCMessageIDSelectContact), QRCMessageDataKey: userInfo}];
}

- (void)deselectContact {
    self.view.backgroundColor = [UIColor colorWithWhite:1.0 alpha:1.0 / 255.0];
    [QRCMessageHandler sendMessageName:QRCMessageNameViewService userInfo:@{QRCMessageIDKey: @(QRCMessageIDDeselectContact)}];
}

// MARK: - UITextFieldDelegate

- (void)textFieldEditingChanged:(UITextField *)textField {
    self.keyword = textField.text;
    [self loadContacts];
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    
    _avatarImageView.hidden = YES;
    
    if (_appeared) {
        [self deselectContact];
    }
    if (_selectedContact) {
        self.selectedContact = nil;
        self.keyword = @"";
        textField.text = self.keyword;
    } else {
        self.keyword = textField.text;
    }

    if (_appeared) [self loadContacts];
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
    if (!self.contacts.count) self.tableView.hidden = YES;

    self.layoutHandler();
}

- (BOOL)textFieldShouldClear:(UITextField *)textField {
    self.selectedContact = nil;
    [self deselectContact];
    
    self.keyword = nil;
    [self loadContacts];
    
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    
    if (_textField.text.length)
    {
        NSString *userIdentifier = _textField.text;
        self.selectedContact = @{QRCUserNameKey: userIdentifier, QRCUserIDKey: userIdentifier};
        _textField.text = self.selectedContact[QRCUserNameKey];
        _avatarImageView.hidden = NO;

        if (CachedImage(userIdentifier)) {
            UIImage *_avatar = (UIImage *)CachedImage(userIdentifier);
            _avatarImageView.qrc_fadeImage = _avatar;
        } else {
            _avatarImageView.qrc_fadeImage = _defaultAvatar;
            NSDictionary *userInfo = @{QRCMessageIDKey: @(QRCMessageIDGetAvatar), QRCMessageDataKey: userIdentifier};
            [QRCMessageHandler sendMessageName:QRCMessageNameApplication appIdentifier:currentAppIdentifier userInfo:userInfo reply:QRCMessageNameSpringBoard handler:^(NSDictionary *userInfo) {
                 NSData *data = nil;
                 if (userInfo) {
                     NSString *result = userInfo[QRCResultKey];
                     data = [[NSData alloc] initWithBase64EncodedString:result options:NSDataBase64DecodingIgnoreUnknownCharacters];
                 }
                 
                 if (data) {
                     UIImage *_avatar = [[UIImage imageWithData:data] qrc_scaleToSize:_defaultAvatar.size];
                     if (_avatar) {
                         _avatarImageView.qrc_fadeImage = _avatar;
                         CacheImage(userIdentifier, _avatar);
                     }
                 }
             }];
        }
        
        self.tableView.hidden = YES;
        [_textField resignFirstResponder];

        NSDictionary *userInfo = @{QRCUserNameKey: _selectedContact[QRCUserNameKey], QRCUserIDKey: _selectedContact[QRCUserIDKey]};
        [self selectContact:userInfo];
    }
    
    return YES;
}

- (void)loadContacts {
    if (!self.selectedContact) self.avatarImageView.image = _defaultAvatar;
    if (self.keyword == nil) self.keyword = @"";
    
    NSDictionary *userInfo = @{QRCMessageIDKey: @(QRCMessageIDGetContacts), QRCMessageDataKey: self.keyword, QRCLimitKey: [prefs stringForKey:QRCRecentContactLimitKey]};
    
    [QRCMessageHandler sendMessageName:QRCMessageNameApplication appIdentifier:currentAppIdentifier userInfo:userInfo reply:QRCMessageNameSpringBoard handler:^(NSDictionary *replyUserInfo)
     {
         [self.contacts removeAllObjects];
         
         NSArray *result = replyUserInfo[QRCResultKey];
         
         if (!result.count && self.keyword.length) {
             [self.contacts addObject:@{QRCUserNameKey: self.keyword, QRCUserIDKey: self.keyword}];
         } else {
             [self.contacts addObjectsFromArray:result];
         }
         
         self.tableView.hidden = NO;
         self.layoutHandler();
         [self.tableView reloadData];
         
         if (needRefreshContacts) {
             needRefreshContacts = NO;
             QRCDispatchAfter(0.8, ^{
                 if (!self.selectedContact) [self loadContacts];
             });
         }
     }];
}

// MARK: - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.contacts.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *contact = self.contacts[indexPath.row];
    
    QRCContactCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier forIndexPath:indexPath];
    
    cell.textLabel.text = contact[QRCUserNameKey];
    cell.timeLabel.text = contact[QRCTimeKey];
    cell.badgeNumber = contact[QRCUnreadCountKey] ? [contact[QRCUnreadCountKey] integerValue] : 0;
    
    if (contact[QRCContentKey]) {
        cell.detailTextLabel.text = contact[QRCContentKey];
    } else if (contact[QRCStatusTextKey]) {
        cell.detailTextLabel.text = contact[QRCStatusTextKey];
    } else {
        if ([(NSString *)contact[QRCUserIDKey] componentsSeparatedByString:@"|"].count > 1) {
            cell.detailTextLabel.text = [(NSString *)contact[QRCUserIDKey] componentsSeparatedByString:@"|"].lastObject;
        } else {
            cell.detailTextLabel.text = contact[QRCUserIDKey];
        }
    }
    
    NSString *userIdentifier = contact[QRCUserIDKey];
    if (CachedImage(userIdentifier)) {
        UIImage *_avatar = (UIImage *)CachedImage(userIdentifier);
        cell.imageView.qrc_fadeImage = _avatar;
    } else {
        cell.imageView.qrc_fadeImage = _defaultAvatar;

        dispatch_async(dispatch_get_main_queue(), ^{
            NSDictionary *userInfo = @{QRCMessageIDKey: @(QRCMessageIDGetAvatar), QRCMessageDataKey: userIdentifier};
            [QRCMessageHandler sendMessageName:QRCMessageNameApplication appIdentifier:currentAppIdentifier userInfo:userInfo reply:QRCMessageNameSpringBoard handler:^(NSDictionary *userInfo)
            {
                 NSData *data = nil;
                 if (userInfo) {
                     NSString *result = userInfo[QRCResultKey];
                     data = [[NSData alloc] initWithBase64EncodedString:result options:NSDataBase64DecodingIgnoreUnknownCharacters];
                 }
                 
                 if (data) {
                     UIImage *_avatar = [[UIImage imageWithData:data] qrc_scaleToSize:_defaultAvatar.size];

                     if (_avatar) {
                         cell.imageView.qrc_fadeImage = _avatar;
                         [cell layoutIfNeeded];
                         CacheImage(userIdentifier, _avatar);
                     }
                 }
            }];
        });
    }
//    }
    
    return cell;
}

// MARK: - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    self.selectedContact = self.contacts[indexPath.row];
    _textField.text = _selectedContact[QRCUserNameKey];
    
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    _avatarImageView.image = cell.imageView.image;
    _avatarImageView.hidden = NO;

    self.tableView.hidden = YES;
    [_textField resignFirstResponder];
    
    NSDictionary *userInfo = @{QRCUserNameKey: _selectedContact[QRCUserNameKey], QRCUserIDKey: _selectedContact[QRCUserIDKey]};
    [self selectContact:userInfo];
}

// MARK: - UIGestureRecognizer

- (void)handlePan:(UIPanGestureRecognizer *)recognizer {
    CGPoint velocity = [recognizer velocityInView:recognizer.view];
    CGPoint location = [(UIPanGestureRecognizer *)recognizer locationInView:recognizer.view];

    if (recognizer.enabled && recognizer.state == UIGestureRecognizerStateChanged) {
        if (location.y > recognizer.view.frame.size.height + 30.0f && velocity.y > 200.0f) {
            recognizer.enabled = NO;
            SBBannerController *bannerController = [NSClassFromString(@"SBBannerController") sharedInstance];
            [bannerController dismissBannerWithAnimation:YES reason:0];
            recognizer.enabled = YES;
        }
    }
}

// MARK: - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer shouldReceiveTouch:(UITouch *)touch {
    if ([recognizer isKindOfClass:UITapGestureRecognizer.class]) {
        return ([touch.view isKindOfClass:NSClassFromString(@"UITableViewCellContentView")])? NO: YES;
    } else if ([recognizer isKindOfClass:UIPanGestureRecognizer.class]) {
        if ([recognizer.view isEqual:self.view]) {
            return YES;
        } else if ([recognizer.view isKindOfClass:NSClassFromString(@"SBBannerContainerView")]) {
            SBBannerController *bannerController = [NSClassFromString(@"SBBannerController") sharedInstance];
            if ([touch.view isKindOfClass:NSClassFromString(@"UITableViewCellContentView")]) return NO;
            return !self.textField.isFirstResponder && bannerController.isShowingModalBanner;
        }
        
        return NO;
    }
    
    return YES;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)recognizer {
    if ([recognizer isKindOfClass:UIPanGestureRecognizer.class] && ([recognizer.view isEqual:self.view] || [recognizer.view isKindOfClass:NSClassFromString(@"SBBannerContainerView")])) {
        CGPoint translation = [(UIPanGestureRecognizer *)recognizer translationInView:recognizer.view];
        return sqrt(translation.y * translation.y) / sqrt(translation.x * translation.x) > 1 && translation.y > 0;
    }
    
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherRecognizer {
    if ([recognizer isKindOfClass:UIPanGestureRecognizer.class]
        && ([recognizer.view isEqual:self.view] || [recognizer.view isKindOfClass:NSClassFromString(@"SBBannerContainerView")])) {
        return YES;
    }
    
    return NO;
}

@end
