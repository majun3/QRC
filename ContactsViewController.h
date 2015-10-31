#import <UIKit/UIKit.h>

@interface QRCContactCell : UITableViewCell

@property (nonatomic, readonly) UILabel *timeLabel;
@property (nonatomic, assign) NSUInteger badgeNumber;

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier;

@end

@interface QRCContactsViewController : UIViewController <UIGestureRecognizerDelegate>

@property (nonatomic, readonly) UITextField *textField;
@property (nonatomic, readonly) UITableView *tableView;
@property (nonatomic, readonly) UIImageView *avatarImageView;
@property (nonatomic, readonly) NSMutableArray *contacts;
@property (nonatomic, retain) NSDictionary *selectedContact;
@property (nonatomic, copy) NSString *keyword;
@property (nonatomic, copy) void (^ layoutHandler)(void);
@property (nonatomic, assign) BOOL appeared;
- (instancetype)initWithFrame:(CGRect)frame;
- (void)loadContacts;

@end
