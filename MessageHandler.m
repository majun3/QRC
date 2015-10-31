#import "libqrc.h"
#import "headers.h"
#import "DLog.h"

#define QRCMHMessageID @"QRCMHMessageID"
#define QRCMHReplyMessageName @"QRCMHReplyMessageName"
#define QRCMHIsReply @"QRCMHIsReply"

static NSUInteger nextMessageIdentifier = 0;
static NSMutableDictionary *messageHandlers = nil;
static NSMutableDictionary *replyHandlers = nil;

@implementation QRCMessageHandler

+ (void)registerMessageName:(NSString *)messageName handler:(QRCIncomingMessageHandler)handler {
    [self registerMessageName:messageName appIdentifier:nil handler:handler];
}

+ (void)registerMessageName:(NSString *)messageName appIdentifier:(NSString *)appIdentifier handler:(QRCIncomingMessageHandler)handler {
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(_messageHandler:) name:messageName object:appIdentifier suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
    if (handler != nil) {
        if (messageHandlers == nil) messageHandlers = [[NSMutableDictionary alloc] init];
        messageHandlers[messageName] = handler;
    }
}

+ (void)unregisterMessageName:(NSString *)messageName {
    [self unregisterMessageName:messageName appIdentifier:nil];
}

+ (void)unregisterMessageName:(NSString *)messageName appIdentifier:(NSString *)appIdentifier {
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self name:messageName object:appIdentifier];
}

+ (void)_messageHandler:(NSNotification*)notification {
    
    NSDictionary *userInfo = notification.userInfo;
    
    if (!userInfo && notification.object) {
        NSData *JSONData = [notification.object dataUsingEncoding:NSUTF8StringEncoding];
        userInfo = [NSJSONSerialization JSONObjectWithData:JSONData options:NSJSONReadingMutableContainers error:nil];
    }
    
    if (userInfo && [userInfo[QRCMHIsReply] boolValue]) {
        
        NSString *messageIdentifier = userInfo[QRCMHMessageID];
        if (messageIdentifier) {
            QRCReplyHandler replyHandler = replyHandlers[messageIdentifier];
            if (replyHandler) {
                replyHandler(userInfo);
            }
            [replyHandlers removeObjectForKey:messageIdentifier];
        }
        
    } else {
        
        QRCIncomingMessageHandler messageHandler = messageHandlers[notification.name];
        if (messageHandler) {
            NSDictionary *reply = messageHandler(userInfo);
            if (reply && userInfo && userInfo[QRCMHMessageID] && userInfo[QRCMHReplyMessageName]) {
                NSMutableDictionary *modifiedReply = [reply mutableCopy];
                modifiedReply[QRCMHIsReply] = [NSNumber numberWithBool:YES];
                modifiedReply[QRCMHMessageID] = userInfo[QRCMHMessageID];
                [self sendMessageName:userInfo[QRCMHReplyMessageName] userInfo:modifiedReply];
            }
        }
    }
}

+ (BOOL)sendMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo {
    return [self sendMessageName:messageName appIdentifier:nil userInfo:userInfo reply:nil handler:nil];
}

+ (BOOL)sendMessageName:(NSString *)messageName appIdentifier:(NSString *)appIdentifier userInfo:(NSDictionary *)userInfo {
    return [self sendMessageName:messageName appIdentifier:appIdentifier userInfo:userInfo reply:nil handler:nil];
}

+ (BOOL)sendMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo reply:(NSString *)reply handler:(QRCReplyHandler)handler {
    return [self sendMessageName:messageName appIdentifier:nil userInfo:userInfo reply:reply handler:handler];
}

+ (BOOL)sendMessageName:(NSString *)messageName appIdentifier:(NSString *)appIdentifier userInfo:(NSDictionary *)userInfo reply:(NSString *)reply handler:(QRCReplyHandler)replyHandler {
    
    if (messageName == nil) {
        return NO;
    }
    
    if (replyHandlers == nil) replyHandlers = [[NSMutableDictionary alloc] init];
    
    NSMutableDictionary *modifiedUserInfo = userInfo ? [userInfo mutableCopy] : [NSMutableDictionary dictionary];
    
    if (reply && replyHandler) {
        NSString *messageIdentifier = [self nextMessageIdentifier];
        modifiedUserInfo[QRCMHMessageID] = messageIdentifier;
        modifiedUserInfo[QRCMHReplyMessageName] = reply;
        
        replyHandlers[messageIdentifier] = replyHandler;
    }
    
    if (appIdentifier) {
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:messageName object:appIdentifier userInfo:modifiedUserInfo deliverImmediately:YES];
    } else {
        NSData *JSONData = [NSJSONSerialization dataWithJSONObject:modifiedUserInfo options:NSJSONWritingPrettyPrinted error:nil];
        NSString *JSONString = JSONData ? [[NSString alloc] initWithData:JSONData encoding:NSUTF8StringEncoding] : @"{}";
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:messageName object:JSONString userInfo:nil deliverImmediately:YES];
    }
    
    return YES;
}

+ (NSDictionary *)sendSynchronousMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo {
    return [self sendSynchronousMessageName:messageName userInfo:userInfo reply:nil];
}

+ (NSDictionary *)sendSynchronousMessageName:(NSString *)messageName userInfo:(NSDictionary *)userInfo reply:(NSString *)reply {
    return [self sendSynchronousMessageName:messageName appIdentifier:nil userInfo:userInfo reply:reply];
}

+ (NSDictionary *)sendSynchronousMessageName:(NSString *)messageName appIdentifier:(NSString *)appIdentifier userInfo:(NSDictionary *)userInfo {
    return [self sendSynchronousMessageName:messageName appIdentifier:appIdentifier userInfo:userInfo reply:nil];
}

+ (NSDictionary *)sendSynchronousMessageName:(NSString*)messageName appIdentifier:(NSString *)appIdentifier userInfo:(NSDictionary *)userInfo reply:(NSString *)reply {
    
    __block BOOL received = NO;
    __block NSDictionary *possibleReply = nil;
    
    BOOL success = [self sendMessageName:messageName appIdentifier:appIdentifier userInfo:userInfo reply:reply handler:^(NSDictionary *reply) {
        received = YES;
        possibleReply = [reply copy];
    }];
    
    if (!success) return nil;
    
    while (!received) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 1.0, YES);
    }
    
    return possibleReply;
}

+ (NSString *)nextMessageIdentifier {
    
    if (++nextMessageIdentifier == 9999) {
        nextMessageIdentifier = 0;
    }
    
    return [NSString stringWithFormat:@"%04d", (int)nextMessageIdentifier];
}

@end
