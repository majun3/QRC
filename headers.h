#import <UIKit/UIKit.h>
#import "DLog.h"

#import <AddressBook/AddressBook.h>

// MARK: - UIKit

@interface UIApplication(private_header)
- (BOOL)launchApplicationWithIdentifier:(id)identifier suspended:(BOOL)suspended;
@end

@interface UIScrollView (CKUtilities)
- (void)__ck_scrollToTop:(BOOL)animated;
- (BOOL)__ck_isScrolledToTop;
- (CGPoint)__ck_scrollToTopContentOffset;
- (void)__ck_scrollToBottom:(BOOL)animated;
- (BOOL)__ck_isScrolledToBottom;
- (CGPoint)__ck_scrollToBottomContentOffset;
- (CGSize)__ck_contentSize;
@end

@interface UIKeyboard : UIView
+(CGSize)defaultSize;
+(CGSize)defaultSizeForInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;
+(CGSize)defaultSizeForOrientation:(int)orientation;
@end

@interface UIImage(Private)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bundleIdentifier format:(int)format scale:(CGFloat)scale;
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bundleIdentifier roleIdentifier:(NSString *)roleIdentifier format:(int)format scale:(CGFloat)scale;
@end

// MARK: - AppSupport

@interface CPDistributedMessagingCenter : NSObject
+ (CPDistributedMessagingCenter*)centerNamed:(NSString*)serverName;
- (void)runServerOnCurrentThread;
- (void)stopServer;
- (void)registerForMessageName:(NSString*)messageName target:(id)target selector:(SEL)selector;
- (void)unregisterForMessageName:(NSString*)messageName;
- (BOOL)sendMessageName:(NSString*)name userInfo:(NSDictionary*)info;
- (BOOL)sendNonBlockingMessageName:(NSString *)message userInfo:(NSDictionary *)userInfo;
- (NSDictionary*)sendMessageAndReceiveReplyName:(NSString*)name userInfo:(NSDictionary*)info;
@end

// MARK: - NSDistributedNotificationCenter

typedef enum {
    NSNotificationSuspensionBehaviorDrop = 1,
    NSNotificationSuspensionBehaviorCoalesce = 2,
    NSNotificationSuspensionBehaviorHold = 3,
    NSNotificationSuspensionBehaviorDeliverImmediately = 4
} NSNotificationSuspensionBehavior;

@interface NSDistributedNotificationCenter : NSNotificationCenter
+ (instancetype)defaultCenter;
- (void)addObserver:(id)notificationObserver selector:(SEL)notificationSelector name:(NSString *)notificationName object:(NSString *)notificationSender suspensionBehavior:(NSNotificationSuspensionBehavior)suspendedDeliveryBehavior;
- (void)removeObserver:(id)notificationObserver name:(NSString *)notificationName object:(NSString *)notificationSender;
- (void)postNotificationName:(NSString *)notificationName object:(NSString *)notificationSender userInfo:(NSDictionary *)userInfo deliverImmediately:(BOOL)deliverImmediately;
@end

// MARK: - BackboardService

typedef NS_ENUM(NSUInteger, BKSProcessAssertionReason)
{
    kProcessAssertionReasonAudio = 1,
    kProcessAssertionReasonLocation,
    kProcessAssertionReasonExternalAccessory,
    kProcessAssertionReasonFinishTask,
    kProcessAssertionReasonBluetooth,
    kProcessAssertionReasonNetworkAuthentication,
    kProcessAssertionReasonBackgroundUI,
    kProcessAssertionReasonInterAppAudioStreaming,
    kProcessAssertionReasonViewServices
};

typedef NS_OPTIONS(NSUInteger, ProcessAssertionFlags)
{
    ProcessAssertionFlagNone = 0,
    ProcessAssertionFlagPreventSuspend         = 1 << 0,
    ProcessAssertionFlagPreventThrottleDownCPU = 1 << 1,
    ProcessAssertionFlagAllowIdleSleep         = 1 << 2,
    ProcessAssertionFlagWantsForegroundResourcePriority  = 1 << 3
};

@interface BKSProcessAssertion : NSObject
@property(readonly, assign, nonatomic) BOOL valid;
- (id)initWithPID:(int)pid flags:(NSUInteger)flags reason:(NSUInteger)reason name:(id)name withHandler:(id)handler;
- (id)initWithBundleIdentifier:(id)bundleIdentifier flags:(NSUInteger)flags reason:(NSUInteger)reason name:(id)name withHandler:(id)handler;
- (void)invalidate;
@end

// MARK: - BulletinBoard

@interface BBAppearance : NSObject
@property (copy, nonatomic) NSString *title;
+ (instancetype)appearanceWithTitle:(NSString *)title;
@end

@interface BBAction : NSObject
@property (copy, nonatomic) NSString *identifier;
@property (assign, nonatomic) NSInteger actionType;
@property (copy, nonatomic) BBAppearance *appearance;
@property (copy, nonatomic) NSString *launchBundleID;
@property (copy, nonatomic) NSURL *launchURL;
@property (copy, nonatomic) NSString *remoteServiceBundleIdentifier;
@property (copy, nonatomic) NSString *remoteViewControllerClassName;
@property (assign, nonatomic) BOOL canBypassPinLock;
@property (assign, nonatomic) BOOL launchCanBypassPinLock;
@property (assign, nonatomic) NSUInteger activationMode;
@property (assign ,nonatomic, getter=isAuthenticationRequired) BOOL authenticationRequired;
@property (nonatomic, copy) id /* block */ internalBlock;
+ (instancetype)action;
+ (instancetype)actionWithIdentifier:(NSString *)identifier;
+ (instancetype)actionWithLaunchBundleID:(NSString *)bundleID;
+ (instancetype)actionWithLaunchBundleID:(NSString *)bundleID callblock:(id /* block */)arg2;
+ (instancetype)actionWithCallblock:(id /* block */)arg1;
+ (instancetype)actionWithLaunchURL:(id)arg1 callblock:(id /* block */)arg2;
- (void)setCallblock:(id /* block */)arg1;
@end

@interface BBButton : NSObject
@property(copy) BBAction * action;
@property(copy) NSString * identifier;
@property(copy) NSString * title;
+ (id)buttonWithTitle:(id)arg1 action:(id)arg2;
+ (id)buttonWithTitle:(id)arg1 action:(id)arg2 identifier:(id)arg3;
+ (id)buttonWithTitle:(id)arg1 glyphData:(id)arg2 action:(id)arg3 identifier:(id)arg4;
+ (id)buttonWithTitle:(id)arg1 image:(id)arg2 action:(id)arg3 identifier:(id)arg4;
- (id)action;
- (id)identifier;
- (id)image;
- (id)title;
- (id)uniqueIdentifier;
@end

@interface BBBulletin : NSObject
@property (copy, nonatomic) NSString *bulletinID;
@property (copy, nonatomic) NSString *sectionID;
@property (copy, nonatomic) NSString *recordID;
@property (copy, nonatomic) NSString *publisherBulletinID;
@property (copy, nonatomic) NSString *title;
@property (copy, nonatomic) NSString *subtitle;
@property (copy, nonatomic) NSString *message;
@property (retain, nonatomic) NSDictionary *context;
@property (copy, nonatomic) NSDictionary *actions;
@property (retain, nonatomic) NSDictionary *supplementaryActionsByLayout;
@property (copy, nonatomic) BBAction *defaultAction;
@property (copy, nonatomic) BBAction *alternateAction;
@property (copy, nonatomic) BBAction *acknowledgeAction;
@property (copy, nonatomic) BBAction *expireAction;
@property (copy, nonatomic) BBAction *raiseAction;
@property (copy, nonatomic) BBAction *snoozeAction;
@property (copy, nonatomic) NSArray *buttons;
- (NSArray *)_allActions;
- (NSArray *)_allSupplementaryActions;
- (NSArray *)supplementaryActions;
- (NSArray *)supplementaryActionsForLayout:(NSInteger)layout;
@end

@interface BBBulletinRequest : BBBulletin
- (void)setContextValue:(id)value forKey:(NSString *)key;
- (void)setSupplementaryActions:(NSArray *)actions;
- (void)setSupplementaryActions:(NSArray *)actions forLayout:(NSInteger)layout;
- (void)generateNewBulletinID;
@end

@interface BBDataProvider : NSObject
@end

extern dispatch_queue_t __BBServerQueue;

#ifdef __cplusplus
extern "C" {
#endif
    void _BBDataProviderAddBulletinForDestinations(BBDataProvider *dataProvider, BBBulletinRequest *bulletin, NSUInteger destinations, BOOL addToLockScreen);
    void BBDataProviderAddBulletinForDestinations(BBDataProvider *dataProvider, BBBulletinRequest *bulletin, NSUInteger destinations);
    void BBDataProviderAddBulletin(BBDataProvider *dataProvider, BBBulletinRequest *bulletin, BOOL allDestinations);
    void BBDataProviderAddBulletinToLockScreen(BBDataProvider *dataProvider, BBBulletinRequest *bulletin);
    void BBDataProviderModifyBulletin(BBDataProvider *dataProvider, BBBulletinRequest *bulletin);
    void BBDataProviderWithdrawBulletinWithPublisherBulletinID(BBDataProvider *dataProvider, NSString *publisherBulletinID);
    void BBDataProviderWithdrawBulletinsWithRecordID(BBDataProvider *dataProvider, NSString *recordID);
    void BBDataProviderInvalidateBulletinsForDestinations(BBDataProvider *dataProvider, NSUInteger destinations);
    void BBDataProviderInvalidateBulletins(BBDataProvider *dataProvider);
    void BBDataProviderReloadDefaultSectionInfo(BBDataProvider *dataProvider);
    void BBDataProviderSetApplicationBadge(BBDataProvider *dataProvider, NSInteger value);
    void BBDataProviderSetApplicationBadgeString(BBDataProvider *dataProvider, NSString *value);
#ifdef __cplusplus
}
#endif



@interface BBServer : NSObject
- (BBDataProvider *)dataProviderForSectionID:(NSString *)sectionID;
- (NSSet *)allBulletinIDsForSectionID:(NSString *)sectionID;
- (NSSet *)bulletinIDsForSectionID:(NSString *)sectionID inFeed:(NSUInteger)feed;
- (NSSet *)bulletinsRequestsForBulletinIDs:(NSSet *)bulletinIDs;
- (NSSet *)bulletinsForPublisherBulletinIDs:(NSSet *)publisherBulletinIDs sectionID:(NSString *)sectionID;
- (void)_publishBulletinRequest:(BBBulletinRequest *)bulletinRequest forSectionID:(NSString *)sectionID forDestinations:(NSUInteger)destinations alwaysToLockScreen:(BOOL)alwaysToLockScreen;
- (void)publishBulletinRequest:(BBBulletinRequest *)bulletinRequest destinations:(NSUInteger)destinations alwaysToLockScreen:(BOOL)alwaysToLockScreen;
@end

// MARK: - SpringBoard

@interface SBLockScreenManager : NSObject
@property(readonly) BOOL isUILocked;
@end

@interface SBApplication : NSObject
- (BOOL)suspendingUnsupported;
- (BOOL)isRunning;
@end

@interface SBApplicationController : NSObject
+ (instancetype)sharedInstance;
- (SBApplication *)applicationWithDisplayIdentifier:(NSString *)identifier;
@end

@interface SpringBoard : UIApplication
- (BOOL)launchApplicationWithIdentifier:(NSString *)identifier suspended:(BOOL)suspended;
@end

@interface SBBulletinBannerController : NSObject
+ (instancetype)sharedInstance;
- (void)modallyPresentBannerForBulletin:(BBBulletin *)bulletin action:(BBAction *)action;
@end

@interface SBUIBannerItem : NSObject
@end

@interface SBBulletinBannerItem : SBUIBannerItem
- (BBBulletin *)seedBulletin;
@end

@interface SBUIBannerContext : NSObject
@property (retain, nonatomic, readonly) SBBulletinBannerItem *item;
@end

@interface SBDefaultBannerTextView : UIView
@property (copy, nonatomic) NSString *primaryText;
@property (copy, nonatomic) NSString *secondaryText;
@property (nonatomic, readonly) UILabel *relevanceDateLabel;
- (void)layoutSubviews;
- (id)initWithFrame:(struct CGRect)arg1;
- (void)setRelevanceDate:(NSDate *)relevanceDate;
@end

@interface SBDefaultBannerView : UIView {
    SBUIBannerContext *_context;
    SBDefaultBannerTextView *_textView;
    UIImageView *_attachmentImageView;
    UIImageView *_iconImageView;
}
- (id)initWithFrame:(CGRect)arg1;
- (id)initWithContext:(id)arg1;
- (CGRect)_contentFrame;
- (CGFloat)_secondaryContentInsetY;
- (CGFloat)_textInsetX;
- (CGFloat)_iconInsetY;
- (void)layoutSubviews;
- (SBUIBannerContext *)bannerContext;
@end

@interface SBBannerContextView : UIView {
    SBDefaultBannerView *_contentView;
    UIView *_separatorView;
    UIView *_contentContainerView;
    UIView *_accessoryView;
    UIView *_pullDownView;
    UIView *_pullDownContainerView;
    UIView *_secondaryContentView;
}
@property(nonatomic) BOOL grabberVisible;
@property(nonatomic) BOOL separatorVisible;
- (SBUIBannerContext *)bannerContext;
- (void)_layoutContentView;
- (void)_layoutContentContainerView;
- (void)_layoutSeparatorView;
- (void)_updateContentAlpha;
@end

@interface SBBannerController : NSObject {
    NSInteger _activeGestureType;
}
+ (instancetype)sharedInstance;
- (SBUIBannerContext *)_bannerContext;
- (SBBannerContextView *)_bannerView;
- (void)dismissBannerWithAnimation:(BOOL)animated reason:(NSInteger)reason;
- (void)_handleGestureState:(NSInteger)state location:(CGPoint)location displacement:(CGFloat)displacement velocity:(CGFloat)velocity;
- (BOOL)isShowingModalBanner;
- (BOOL)isShowingBanner;
@end

@interface SBBannerContainerView : UIView
@property(nonatomic) UIView *inlayContainerView;
@property(nonatomic) UIView *inlayView;
@property(nonatomic) UIView *backgroundView;
@end

@interface SBBannerContainerViewController : UIViewController {
    SBBannerContainerView *_containerView;
    CGFloat _maximumBannerHeight;
    CGRect _keyboardFrame;
}
@property(nonatomic) UIView *backgroundView;
@property(readonly, nonatomic) SBBannerContextView *bannerContextView;
@property(readonly, nonatomic) BOOL canPullDown;
- (BBBulletinRequest *)_bulletin;
- (CGFloat)_maximumPullDownViewHeight;
- (CGFloat)_bannerContentHeight;
- (CGFloat)_miniumBannerContentHeight;
- (CGFloat)preferredMaximumHeight;
- (CGFloat)_pullDownViewHeight;
- (CGFloat)_preferredPullDownViewHeight;
@end

@interface SBNotificationCenterViewController : UIViewController

@end

@interface SBNotificationCenterController : NSObject
@property(readonly, retain, nonatomic) SBNotificationCenterViewController *viewController;
@property(readonly, nonatomic, getter=isVisible) BOOL visible;
+ (id)sharedInstance;
- (void)dismissAnimated:(BOOL)arg1;
@end

// MARK: - NotificationsUI

@interface NCInteractiveNotificationViewController : UIViewController {
    NSDictionary *_context;
}
@property(nonatomic) CGFloat maximumHeight;
@property(nonatomic, getter=isModal) BOOL modal;
@property(copy, nonatomic) NSDictionary *context;
- (id)actionTitles;
- (id)actionContext;
- (void)setActionEnabled:(BOOL)arg1 atIndex:(NSInteger)arg2;
- (void)handleActionAtIndex:(NSInteger)arg1;
- (void)willPresentFromActionIdentifier:(id)arg1;
- (void)dismissWithContext:(id)arg1;
- (double)preferredContentHeight;
- (void)requestPreferredContentHeight:(CGFloat)arg1;
@end

// MARK: - IMCore
@interface IMDirectlyObservableObject : NSObject
@property (retain) NSArray *observers;
@end
@interface IMHandle : IMDirectlyObservableObject
@property(retain, nonatomic) NSString *originalID;
- (id)init;
- (void)setFirstName:(id)arg1 lastName:(id)arg2;
- (void)setFirstName:(id)arg1 lastName:(id)arg2 fullName:(id)arg3 andUpdateABPerson:(BOOL)arg4;
@end

@interface IMHandleRegistrar : NSObject
+ (id)sharedInstance;
- (id)allIMHandles;
- (void)registerIMHandle:(id)arg1;
- (void)unregisterIMHandle:(id)arg1;
@end

@interface IMChat : NSObject
@property (nonatomic, readonly) NSString *chatIdentifier;
@property (retain, nonatomic) NSString *displayName;
@property (retain, nonatomic) IMHandle *recipient;
@property (nonatomic, readonly) NSArray *participants;
@property (nonatomic, readonly) NSArray *chatItems;
@property (assign, nonatomic) NSUInteger numberOfMessagesToKeepLoaded;
- (NSInteger)__ck_watermarkMessageID;
- (NSString *)loadMessagesBeforeDate:(NSDate *)date limit:(NSUInteger)limit loadImmediately:(BOOL)immediately;
@end

@class IMChatItem;

@interface IMItem : NSObject
@property (retain, nonatomic) NSDate *time;
@property (retain, nonatomic) id context;
- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
- (IMChatItem *)_newChatItems;
@property(retain, nonatomic) NSString *account;
@property (nonatomic, retain) NSString *sender;
@property(retain, nonatomic) NSString *handle;
@property(nonatomic) long long messageID;
@property (nonatomic, retain) NSString *service;
- (void)_updateContextWithSenderHandle:(id)arg1 otherHandle:(id)arg2;
@end

@interface IMMessageItem : IMItem
@property(nonatomic) long long expireState;
@property (retain, nonatomic) NSString *subject;
@property (retain, nonatomic) NSAttributedString *body;
@property (retain, nonatomic) NSString *plainBody;
@property (retain, nonatomic) NSData *bodyData;
@property (retain, nonatomic) NSDate *timeDelivered;
@property (retain, nonatomic) NSDate *timeRead;
@property (assign, nonatomic) NSUInteger flags;
@property (assign, nonatomic) NSUInteger errorCode;
@property(readonly, nonatomic) BOOL isPlayed;
@property(readonly, nonatomic) BOOL isExpirable;
@property(readonly, nonatomic) BOOL isAudioMessage;
@property(readonly, nonatomic) BOOL isRead;
@property(readonly, nonatomic) BOOL isEmpty;
@property(readonly, nonatomic) BOOL isFinished;
@end

@interface IMMessage : NSObject
@property (nonatomic, retain) IMHandle *sender;
+ (instancetype)messageFromIMMessageItem:(IMMessageItem *)item sender:(id)sender subject:(id)subject;
@end

@interface IMChatItem : NSObject
- (IMItem *)_item;
- (id)_initWithItem:(id)arg1;
@end

@interface IMTranscriptChatItem : IMChatItem
@end

@interface IMMessageChatItem : IMTranscriptChatItem
@property (readonly, copy) NSString *debugDescription;
@property (readonly, copy) NSString *description;
@property (nonatomic, readonly) BOOL failed;
@property (readonly) unsigned int hash;
@property (nonatomic, readonly) BOOL isFromMe;
@property (nonatomic, readonly, retain) IMMessage *message;
@property (nonatomic, readonly, retain) IMHandle *sender;
@property (readonly) Class superclass;
@property (nonatomic, readonly, retain) NSDate *time;
@end
@interface IMMessagePartChatItem : IMMessageChatItem
+ (id)_messageItemWithPartsDeleted:(id)arg1 fromMessageItem:(id)arg2;
+ (id)_newMessagePartsForMessageItem:(id)arg1;
- (id)_initWithItem:(id)arg1 text:(id)arg2 index:(int)arg3;
@end
@interface IMTextMessagePartChatItem : IMMessagePartChatItem
- (id)_initWithItem:(id)arg1 text:(id)arg2 index:(int)arg3 subject:(id)arg4;
@end

@interface IMAttachmentMessagePartChatItem : IMMessagePartChatItem
@property (nonatomic, readonly, copy) NSString *transferGUID;
- (id)_initWithItem:(id)arg1 text:(id)arg2 index:(int)arg3 transferGUID:(id)arg4;
@end

@interface IMSenderChatItem : IMTranscriptChatItem
@property(retain,readonly) IMHandle * handle;
- (id)_initWithItem:(id)arg1 handle:(id)arg2;
@end

@interface IMDateChatItem : IMTranscriptChatItem
- (id)_initWithItem:(id)arg1;
@end

extern NSString *IMAttachmentCharacterString;
extern NSString *IMMessagePartAttributeName;
extern NSString *IMFileTransferGUIDAttributeName;
extern NSString *IMFilenameAttributeName;
extern NSString *IMInlineMediaWidthAttributeName;
extern NSString *IMInlineMediaHeightAttributeName;
extern NSString *IMBaseWritingDirectionAttributeName;
extern NSString *IMFileTransferAVTranscodeOptionAssetURI;
extern NSString *IMStripFormattingFromAddress(NSString *formattedAddress);

// MARK: - ChatKit

@interface CKMediaObject : NSObject
+ (id)UTITypes;
- (id)initWithTransfer:(id)arg1;
@property (copy, nonatomic, readonly) NSString *transferGUID;
@property (copy, nonatomic, readonly) NSURL *fileURL;
@property(readonly, copy, nonatomic) NSData *data;
@property(readonly, nonatomic) NSUInteger mediaType;
@property(readonly, copy, nonatomic) NSString *mimeType;
@property(retain, nonatomic) id /*<CKFileTransfer>*/transfer;
@end
@interface CKImageMediaObject : CKMediaObject
+ (id)UTITypes;
@end
@interface CKAVMediaObject : CKMediaObject
@property(nonatomic) double duration;
@end
@interface CKAudioMediaObject : CKAVMediaObject
+ (id)UTITypes;
- (id)previewItemTitle;
- (int)mediaType;
@end

@interface CKMediaObjectManager : NSObject
+ (instancetype)sharedInstance;
- (CKMediaObject *)mediaObjectWithFileURL:(NSURL *)url filename:(NSString *)filename transcoderUserInfo:(NSDictionary *)transcoderUserInfo;
- (CKMediaObject *)mediaObjectWithData:(NSData *)data UTIType:(NSString *)type filename:(NSString *)filename transcoderUserInfo:(NSDictionary *)transcoderUserInfo;
@end

typedef NS_ENUM(SInt8, CKBalloonColor) {
    CKBalloonColorGray   = -1,
    CKBalloonColorGreen  =  0,
    CKBalloonColorBlue   =  1,
    CKBalloonColorWhite  =  2,
    CKBalloonColorRed    =  3,
};

@interface CKUIBehavior : NSObject
+ (instancetype)sharedBehaviors;
- (UIEdgeInsets)transcriptMarginInsets;
- (UIEdgeInsets)balloonTranscriptInsets;
- (CGFloat)leftBalloonMaxWidthForTranscriptWidth:(CGFloat)transcriptWidth marginInsets:(UIEdgeInsets)marginInsets;
- (CGFloat)rightBalloonMaxWidthForEntryContentViewWidth:(CGFloat)entryContentViewWidth;
- (CGFloat)transcriptContactImageDiameter;
- (UIColor *)transcriptBackgroundColor;
- (BOOL)transcriptCanUseOpaqueMask;
- (BOOL)photoPickerShouldZoomOnSelection;
- (NSArray *)balloonColorsForColorType:(CKBalloonColor)colorType;
- (UIColor *)unfilledBalloonColorForColorType:(CKBalloonColor)colorType;
- (UIColor *)balloonTextColorForColorType:(CKBalloonColor)colorType;
- (UIColor *)balloonTextLinkColorForColorType:(CKBalloonColor)colorType;
- (UIColor *)balloonOverlayColorForColorType:(CKBalloonColor)colorType;
- (UIColor *)chevronImageForColorType:(CKBalloonColor)colorType;
- (UIColor *)waveformColorForColorType:(CKBalloonColor)colorType;
- (UIColor *)progressViewColorForColorType:(CKBalloonColor)colorType;
- (UIColor *)recipientTextColorForColorType:(CKBalloonColor)colorType;
- (UIColor *)sendButtonColorForColorType:(CKBalloonColor)colorType;

// 9.x
@property (nonatomic, readonly) struct UIEdgeInsets minTranscriptMarginInsets;
- (CGFloat)balloonMaxWidthForTranscriptWidth:(CGFloat)arg1 marginInsets:(UIEdgeInsets)arg2 shouldShowPhotoButton:(BOOL)arg3 shouldShowCharacterCount:(BOOL)arg4;
@end

typedef NS_ENUM(SInt8, CKBalloonOrientation) {
    CKBalloonOrientationLeft  = 0,
    CKBalloonOrientationRight = 1
};

@interface CKBalloonImageView : UIView
@end

@interface CKBalloonView : CKBalloonImageView
@property (assign, nonatomic) CKBalloonOrientation orientation;
@property (assign, nonatomic) BOOL hasTail;
@property (assign, nonatomic, getter=isFilled) BOOL filled;
@property (assign, nonatomic) BOOL canUseOpaqueMask;
- (void)prepareForReuse;
- (void)prepareForDisplay;
- (void)setNeedsPrepareForDisplay;
- (void)prepareForDisplayIfNeeded;
@end

@interface CKColoredBalloonView : CKBalloonView
@property (assign, nonatomic) CKBalloonColor color;
@property (assign, nonatomic) BOOL wantsGradient;
@end

@interface CKTextBalloonView : CKColoredBalloonView
@property (copy, nonatomic) NSAttributedString *attributedText;
@end

@interface CKEditableCollectionViewCell : UICollectionViewCell
@end

@interface CKTranscriptCell : CKEditableCollectionViewCell
@property (assign, nonatomic) BOOL wantsDrawerLayout;
@end

@interface CKTranscriptHeaderCell : CKTranscriptCell
@end

@interface CKTranscriptLabelCell : CKTranscriptCell
@end

@interface CKTranscriptMessageCell : CKTranscriptCell
@property (assign, nonatomic) BOOL wantsContactImageLayout;
@property (retain, nonatomic) UIImage *contactImage;
@end

@interface CKTranscriptStatusCell : CKTranscriptLabelCell
@end

@interface CNAvatarView : UIControl
@property (nonatomic, retain) UIButton *imageButton;
@end
@interface CKAvatarView : CNAvatarView
@end

@interface CKPhoneTranscriptMessageCell : CKTranscriptMessageCell
@property (nonatomic, retain) CKAvatarView *avatarView;
- (void)setShowAvatarView:(BOOL)arg1 withContact:(id)arg2 preferredHandle:(id)arg3 avatarViewDelegate:(id)arg4;
@end

@interface CKTranscriptBalloonCell : CKPhoneTranscriptMessageCell // 9.x
@property (retain, nonatomic) CKBalloonView *balloonView;
@property (copy, nonatomic) NSAttributedString *drawerText;
@end

@interface CKAddressBook : NSObject
+ (UIImage *)transcriptContactImageOfDiameter:(CGFloat)diameter forRecordID:(ABRecordID)recordID;
@end

@interface CKEntity : NSObject
@property (copy, nonatomic, readonly) NSString *name;
@property (copy, nonatomic, readonly) NSString *rawAddress;
@property (retain, nonatomic, readonly) UIImage *transcriptContactImage;
+ (instancetype)copyEntityForAddressString:(NSString *)addressString;
@end

@interface CKComposition : NSObject
@property (copy, nonatomic) NSAttributedString *subject;
@property (copy, nonatomic) NSAttributedString *text;
@property (retain, nonatomic, readonly) NSArray *mediaObjects;
@property (nonatomic, readonly) BOOL hasContent;
@property (nonatomic, readonly) BOOL hasNonwhiteSpaceContent;
+ (instancetype)composition;
+ (instancetype)photoPickerCompositionWithMediaObjects:(NSArray *)mediaObjects;
- (instancetype)compositionByAppendingComposition:(CKComposition *)composition;
@end

@interface CKConversation : NSObject
@property (retain, nonatomic) IMChat *chat;
@property (assign, nonatomic) NSUInteger limitToLoad;
- (void)markAllMessagesAsRead;
@end

@interface CKMessageEntryTextView : UITextView
@end
@interface CKMessageEntryRichTextView : CKMessageEntryTextView
@property(retain, nonatomic) NSMutableDictionary *composeImages;
@property(retain, nonatomic) NSMutableDictionary *mediaObjects;
- (void)setCompositionText:(id)arg1;
@end
@interface CKMessageEntryContentView : UIScrollView <UITextViewDelegate>
@property(retain, nonatomic) CKMessageEntryTextView *subjectView;
@property(retain, nonatomic) CKMessageEntryRichTextView *textView;
@property(readonly, nonatomic, getter=isActive) BOOL active;
@property(retain, nonatomic) CKComposition *composition;
- (BOOL)makeActive;
- (void)textViewDidChange:(UITextView *)textView;
- (void)textViewDidEndEditing:(UITextView *)textView;
- (void)textViewDidBeginEditing:(UITextView *)textView;
- (BOOL)textViewShouldBeginEditing:(UITextView *)textView;
@end
@interface CKMessageEntryRecordedAudioView : UIView
@property(retain, nonatomic) CKAudioMediaObject *audioMediaObject;
@end
@interface CKMessageEntryView : UIView <UIGestureRecognizerDelegate>
@property(retain, nonatomic) CKConversation *conversation;
@property(retain, nonatomic) CKComposition *composition;
@property(assign, nonatomic) BOOL shouldShowSendButton;
@property(assign, nonatomic) BOOL shouldShowSubject;
@property(assign, nonatomic) BOOL shouldShowPhotoButton;
@property(assign, nonatomic) BOOL shouldShowCharacterCount;
@property(retain, nonatomic) CKMessageEntryContentView *contentView;
@property(retain, nonatomic) UIButton *sendButton;
@property(retain, nonatomic) UIButton *photoButton;
@property(retain, nonatomic) UIButton *audioButton;
@property(readonly, nonatomic, getter=isRecording) BOOL recording;
@property(retain, nonatomic) CKMessageEntryRecordedAudioView *recordedAudioView;
- (instancetype)initWithFrame:(CGRect)frame shouldShowSendButton:(BOOL)sendButton shouldShowSubject:(BOOL)subject shouldShowPhotoButton:(BOOL)photoButton shouldShowCharacterCount:(BOOL)characterCount;
- (void)updateEntryView;
- (BOOL)photoButtonEnabled;
- (BOOL)sendButtonEnabled;
- (void)touchUpInsideSendButton:(UIButton *)button;
@end

@protocol CKMessageEntryViewDelegate <NSObject>
@required
- (void)messageEntryViewDidChange:(CKMessageEntryView *)entryView;
- (BOOL)messageEntryViewShouldBeginEditing:(CKMessageEntryView *)entryView;
- (void)messageEntryViewDidBeginEditing:(CKMessageEntryView *)entryView;
- (void)messageEntryViewDidEndEditing:(CKMessageEntryView *)entryView;
- (void)messageEntryViewRecordingDidChange:(CKMessageEntryView *)entryView;
- (BOOL)messageEntryView:(CKMessageEntryView *)entryView shouldInsertMediaObjects:(NSArray *)mediaObjects;
- (void)messageEntryViewSendButtonHit:(CKMessageEntryView *)entryView;
- (void)messageEntryViewSendButtonHitWhileDisabled:(CKMessageEntryView *)entryView;
- (void)messageEntryViewRaiseGestureAutoSend:(CKMessageEntryView *)entryView;
@optional
- (BOOL)getContainerWidth:(double*)arg1 offset:(double*)arg2;
@end

@interface MFHeaderLabelView : UILabel
+ (id)_defaultColor;
- (struct CGPoint)baselinePoint;
- (id)effectiveTextColor;
- (id)initWithFrame:(struct CGRect)arg1;
@end

@interface MFComposeHeaderView : UIView {
    id _delegate;
    MFHeaderLabelView *_labelView;
}
@property(readonly, nonatomic) MFHeaderLabelView *labelView;
+ (double)_labelTopPaddingSpecification;
+ (double)separatorHeight;
+ (double)preferredHeight;
+ (id)defaultFont;
- (void)setFrame:(struct CGRect)arg1;
- (void)refreshPreferredContentSize;
- (void)setDelegate:(id)arg1;
- (void)touchesEnded:(id)arg1 withEvent:(id)arg2;
- (void)handleTouchesEnded;
- (struct CGRect)titleLabelBaselineAlignmentRectForLabel:(id)arg1;
@property(copy, nonatomic) NSString *label;
- (id)initWithFrame:(struct CGRect)arg1;
@end

@interface MFComposeRecipientTextView : MFComposeHeaderView
@end

@interface CKComposeRecipientView : MFComposeRecipientTextView
@end

@interface CKChatItem : NSObject
@property (retain, nonatomic) IMTranscriptChatItem *IMChatItem;
@property (copy, nonatomic) NSAttributedString *transcriptText;
@property (copy, nonatomic) NSAttributedString *transcriptDrawerText;
- (id)initWithIMChatItem:(id)arg1 maxWidth:(double)arg2;
@end

@interface CKBalloonTextView : UITextView
@end

@class CKBalloonView, CKMovieBalloonView;

@interface CKBalloonChatItem : CKChatItem
@property(readonly, retain, nonatomic) NSDate *time;
@property(readonly, nonatomic, getter=isFromMe) _Bool fromMe;
@property(readonly, nonatomic) BOOL balloonOrientation;
- (BOOL)wantsDrawerLayout;
- (id)contactImage;
- (BOOL)transcriptOrientation;
@end

@interface CKMessagePartChatItem : CKBalloonChatItem
@property(readonly, nonatomic) BOOL color;
@property(readonly, retain, nonatomic) IMMessage *message;
- (id)sender;
- (id)time;
- (BOOL)failed;
- (BOOL)isFromMe;
@end
@interface CKAttachmentMessagePartChatItem : CKMessagePartChatItem
@property(retain, nonatomic) CKMediaObject *mediaObject;
@property(readonly, copy, nonatomic) NSString *transferGUID;
- (id)initWithIMChatItem:(id)arg1 maxWidth:(double)arg2;
@end
@interface CKExpirableMessageChatItem : CKAttachmentMessagePartChatItem
@end
@interface CKAudioMessageChatItem : CKExpirableMessageChatItem
@property(retain, nonatomic) CKAudioMediaObject *mediaObject;
@end

@protocol CKBalloonViewDelegate <NSObject>
- (void)balloonViewWillResignFirstResponder:(CKBalloonView *)balloonView;
- (void)balloonViewTapped:(CKBalloonView *)balloonView;
- (void)balloonView:(CKBalloonView *)balloonView performAction:(SEL)action withSender:(id)sender;
- (BOOL)balloonView:(CKBalloonView *)balloonView canPerformAction:(SEL)action withSender:(id)sender;
- (CGRect)calloutTargetRectForBalloonView:(CKBalloonView *)balloonView;
- (BOOL)shouldShowMenuForBalloonView:(CKBalloonView *)balloonView;
- (NSArray *)menuItemsForBalloonView:(CKBalloonView *)balloonView;
- (void)balloonViewDidFinishDataDetectorAction:(CKBalloonView *)balloonView;
@end

@protocol CKMovieBalloonViewDelegate <CKBalloonViewDelegate>
@required
- (void)balloonView:(CKMovieBalloonView *)balloonView mediaObjectDidFinishPlaying:(id)mediaObject;
@end

@protocol CKLocationShareBalloonViewDelegate <CKBalloonViewDelegate>
@required
- (void)locationShareBalloonViewShareButtonTapped:(id)balloonView;
- (void)locationShareBalloonViewIgnoreButtonTapped:(id)balloonView;
@end

@interface CKViewController : UIViewController
@end

@interface CKEditableCollectionView : UICollectionView
@end

@interface CKTranscriptCollectionView : CKEditableCollectionView
@end

@protocol CKAudioControllerDelegate <NSObject>
@optional
- (void)audioControllerPlayingDidChange:(id)arg1;
- (void)audioControllerDidStop:(id)arg1;
- (void)audioControllerDidPause:(id)arg1;
- (void)audioController:(id)arg1 mediaObjectProgressDidChange:(id)arg2 currentTime:(double)arg3 duration:(double)arg4;
- (void)audioController:(id)arg1 mediaObjectDidFinishPlaying:(id)arg2;
@end

@interface CKAudioController : NSObject
@property(nonatomic) id <CKAudioControllerDelegate> delegate;
@property(retain, nonatomic, setter=_setMediaObjects:) NSMutableArray *_mediaObjects;
@property(readonly, retain, nonatomic) CKMediaObject *currentMediaObject;
@property(readonly, retain, nonatomic) NSArray *mediaObjects;
- (id)initWithMediaObjects:(id)arg1;
- (void)addMediaObjects:(id)arg1;
- (void)addMediaObject:(id)arg1;
- (void)stop;
- (void)pause;
- (void)play;
@end

@class CKTranscriptCell;
@interface CKTranscriptCollectionViewController : CKViewController <UICollectionViewDataSource, UICollectionViewDelegate, CKMovieBalloonViewDelegate, CKLocationShareBalloonViewDelegate, CKAudioControllerDelegate, UIAlertViewDelegate>
@property (retain, nonatomic) CKConversation *conversation;
@property (copy, nonatomic) NSArray *chatItems;
@property (retain, nonatomic) CKTranscriptCollectionView *collectionView;
@property (nonatomic, readonly) CGFloat leftBalloonMaxWidth;
@property (nonatomic, readonly) CGFloat rightBalloonMaxWidth;
@property(retain, nonatomic) CKAudioController *audioController;
- (instancetype)initWithConversation:(CKConversation *)conversation rightBalloonMaxWidth:(CGFloat)rightBalloonMaxWidth leftBalloonMaxWidth:(CGFloat)leftBalloonMaxWidth; // < 9.x
- (CKChatItem *)chatItemWithIMChatItem:(IMChatItem *)imChatItem;
- (void)configureCell:(CKTranscriptCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath;
- (NSIndexPath *)indexPathForBalloonView:(id)arg1;
- (void)alertView:(UIAlertView *)arg1 didDismissWithButtonIndex:(NSInteger)arg2;
- (void)reloadData;
// 9.x
- (instancetype)initWithConversation:(CKConversation *)conversation balloonMaxWidth:(CGFloat)arg2 marginInsets:(UIEdgeInsets)arg3;
@end

@interface CKInlineReplyViewController : NCInteractiveNotificationViewController <CKMessageEntryViewDelegate>
@property(retain, nonatomic) CKMessageEntryView *entryView;
@property(nonatomic) BOOL shouldShowKeyboard;
- (id)init;
- (void)setupView;
- (void)setupConversation;
- (void)setContext:(id)arg1;
- (void)handleActionIdentifier:(id)arg1;
- (void)sendMessage;
- (void)messageEntryViewSendButtonHit:(id)arg1;
- (void)willPresentFromActionIdentifier:(id)arg1;
- (void)dismissWithContext:(id)arg1;
- (void)messageEntryViewDidChange:(id)arg1;
- (void)playSendSoundForMessage:(id)arg1;
- (void)updateSendButton;
- (void)updateTyping;
- (void)interactiveNotificationDidAppear;
@end

// MARK: - QRC

@class QRCPhotoPickerController, QRCContactsViewController;

@interface SBNotificationCenterViewController(QRC)
- (void)qrc_handleTap:(id)sender;
@end

@interface CKChatItem(QRC)
@property(copy, nonatomic) NSString *userIdentifier;
@end

@interface SBBannerContainerViewController(QRC)
@property (retain, nonatomic) QRCContactsViewController *contactViewController;
- (CGFloat)keyboardHeight;
- (void)qrc_handlePan:(UIPanGestureRecognizer *)recognizer;
@end

@interface QRCConversationViewController : CKTranscriptCollectionViewController
- (void)refreshData;
@end

@interface QRCInlineReplyViewController : CKInlineReplyViewController <UIGestureRecognizerDelegate>
@property (strong, nonatomic) QRCConversationViewController *conversationViewController;
@property (strong, nonatomic) QRCPhotoPickerController *photoPickerController;
@property (strong, nonatomic) UIActivityIndicatorView *activityIndicatorView;
- (void)selectedContact:(NSDictionary*)userInfo;
- (void)deselectedContact;
- (void)photoButtonTapped:(UIButton *)button;
- (BOOL)isComposeMode;
- (void)handlePan:(UIPanGestureRecognizer *)recognizer;
- (void)handleDoubleTap:(UITapGestureRecognizer *)recognizer;
@end

// Settings
#define QRCSimpleModeComposeKey  @"SimpleModeCompose"
#define QRCSimpleModeReplyKey  @"SimpleModeReply"
#define QRCReturnAsSendKey  @"ReturnAsSend"
#define QRCQuitAppWhenSleepKey  @"QuitAppWhenSleep"
#define QRCPlaySoundKey @"PlaySound"
#define QRCVibrateKey @"Vibrate"
#define QRCRecentContactLimitKey @"RecentContactLimit"
#define QRCDismissAfterSendKey @"DismissAfterSend"
