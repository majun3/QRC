#import <UIKit/UIKit.h>

// MARK: - Constants

#define SpringBoardIdentifier @"com.apple.springboard"

#define QRCAppIdentifierKey @"appIdentifier"
#define QRCProcessNameKey @"processName"
#define QRCNotificationUserIDKey @"notificationUserIDKey"
#define QRCPackageIdentifierKey @"packageIdentifier"
#define QRCInformationKey @"information"
#define QRCRetryUnsentMessageKey @"RetryUnsentMessage"

#define QRCUserIDKey @"userID"
#define QRCUserNameKey @"username"
#define QRCStatusTextKey @"statusText"
#define QRCContentKey @"content"
#define QRCImagesKey @"images"
#define QRCFilePathKey @"filePath"
#define QRCTypeKey @"type"
#define QRCOutgoingKey @"outgoing"
#define QRCTimeKey @"time"
#define QRCUnreadCountKey @"unreadCount"
#define QRCResultKey @"result"
#define QRCLeftBalloonColorKey  @"leftBalloonColor"
#define QRCRightBalloonColorKey @"rightBalloonColor"
#define QRCLeftTextColorKey  @"leftTextColor"
#define QRCRightTextColorKey @"rightTextColor"
#define QRCLimitKey @"limit"
#define QRCErrorKey @"error"

#define QRCMessageNameSpringBoard @"QRCMessageNameSpringBoard"
#define QRCMessageNameViewService @"QRCMessageNameViewService"
#define QRCMessageNameApplication @"QRCMessageNameApplication"

#define QRCMessageIDKey   @"messageID"
#define QRCMessageDataKey @"messageData"

#define QRCEnabledKey @"Enabled"
#define QRCComposeIconKey @"ComposeIcon"
#define QRCAuthenticationRequiredKey @"AuthenticationRequired"

#define QRCAvatarSize CGSizeMake(28.0, 28.0)

// MARK: - enum

typedef NS_ENUM(SInt32, QRCMessageID) {
    QRCMessageIDSendMessage,
    QRCMessageIDGetContacts,
    QRCMessageIDGetAvatar,
    QRCMessageIDGetMessages,
    QRCMessageIDSendResult,
    QRCMessageIDSelectContact,
    QRCMessageIDDeselectContact,
    QRCMessageIDSetActivate,
    QRCMessageIDAppWillTerminate,
    QRCMessageIDSwitchToSelectContact,
    QRCMessageIDLoadMessages,
    QRCMessageIDPhotoPicker,
    QRCMessageIDMarkAsRead,
    QRCMessageIDClearNotifications,
    QRCMessageIDRetryUnsentMessages
};

typedef NS_ENUM(SInt32, QRCMessageType) {
    QRCMessageTypeText,
    QRCMessageTypeImage,
    QRCMessageTypeTime,
    QRCMessageTypeSender,
    QRCMessageTypeAudio,
    QRCMessageTypeVideo
};

// MARK: - QRCTweak

@protocol QRCTweak <NSObject>

@required
- (NSDictionary *)information;

@optional
- (NSDictionary *)balloonColor;
- (UIImage *)composeIcon;
- (void)compose;

@end

@interface QRCBaseTweak : NSObject
- (void)registerRetryUserNotificationSettings;
- (void)sendUnsentLocalNotificationWithUserID:(NSString *)userID messageID:(NSString *)messageID messageText:(NSString *)messageText;
- (void)cancelAllUnsentLocalNotifications;
- (void)sendSentResultMessage:(BOOL)result;
@end

@class BBBulletinRequest;

#ifdef __cplusplus
extern "C" {
#endif
    void QRCRegisterTweak(id<QRCTweak> tweak);
    void QRCUnregisterTweak(NSString *name);
    
    void QRCPresentComposer(NSDictionary *appInfo);
    void QRCModifyBulletinRequest(BBBulletinRequest *request, NSDictionary *appInfo);
    
    void QRCDispatchAfter(CGFloat delay, void (^block)(void));
    NSString * QRCLocalizedString(NSString *key);

#ifdef __cplusplus
}
#endif

// MARK: - QRCMessageHandler

typedef NSDictionary *(^QRCIncomingMessageHandler)(NSDictionary *userInfo);
typedef void(^QRCReplyHandler)(NSDictionary *userInfo);

@interface QRCMessageHandler : NSObject

+ (void)registerMessageName:(NSString *)messageName handler:(QRCIncomingMessageHandler)handler;
+ (void)registerMessageName:(NSString *)messageName appIdentifier:(NSString *)appIdentifier handler:(QRCIncomingMessageHandler)handler;

+ (void)unregisterMessageName:(NSString *)messageName;
+ (void)unregisterMessageName:(NSString *)messageName appIdentifier:(NSString *)appIdentifier;

+ (BOOL)sendMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo;
+ (BOOL)sendMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo reply:(NSString *)reply handler:(QRCReplyHandler)handler;
+ (BOOL)sendMessageName:(NSString *)messageName appIdentifier:(NSString *)appIdentifier userInfo:(NSDictionary *)userInfo;
+ (BOOL)sendMessageName:(NSString *)messageName appIdentifier:(NSString *)appIdentifier userInfo:(NSDictionary *)userInfo reply:(NSString *)reply handler:(QRCReplyHandler)handler;

+ (NSDictionary *)sendSynchronousMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo;
+ (NSDictionary *)sendSynchronousMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo reply:(NSString *)reply;
+ (NSDictionary *)sendSynchronousMessageName:(NSString *)messageName appIdentifier:(NSString *)appIdentifier userInfo:(NSDictionary *)userInfo;
+ (NSDictionary *)sendSynchronousMessageName:(NSString *)messageName appIdentifier:(NSString *)appIdentifier userInfo:(NSDictionary *)userInfo reply:(NSString *)reply;

@end

// MARK: - Categories

@interface UIImage(QRC)

- (UIImage *)qrc_scaleToSize:(CGSize)size;
- (UIImage *)qrc_applyCornerRadius:(CGFloat)cornerRadius;

@end

@interface UIImageView(QRC)

@property (nonatomic, assign) UIImage *qrc_fadeImage;
- (UIImage *)qrc_fadeImage;
- (void)setQrc_fadeImage:(UIImage *)image;

@end
