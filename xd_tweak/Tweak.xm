#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// ========== 1. swizzle NSUserDefaults ==========
%hook NSUserDefaults
- (id)objectForKey:(NSString *)key {
    id orig = %orig;
    NSString *k = [key lowercaseString];
    if ([k containsString:@"vip"] || [k containsString:@"member"] ||
        [k containsString:@"expire"] || [k containsString:@"auth"] ||
        [k containsString:@"paid"] || [k containsString:@"purchas"]) {
        if ([k containsString:@"expire"] || [k containsString:@"time"] || [k containsString:@"date"]) {
            return @9999999999;
        }
        if ([k containsString:@"vip"] || [k containsString:@"member"] || [k containsString:@"auth"]) {
            return @YES;
        }
    }
    return orig;
}
- (BOOL)boolForKey:(NSString *)key {
    NSString *k = [key lowercaseString];
    if ([k containsString:@"vip"] || [k containsString:@"member"] ||
        [k containsString:@"paid"] || [k containsString:@"unlock"] ||
        [k containsString:@"auth"] || [k containsString:@"purchas"]) {
        return YES;
    }
    return %orig;
}
- (NSInteger)integerForKey:(NSString *)key {
    NSString *k = [key lowercaseString];
    if ([k containsString:@"vip"] || [k containsString:@"member"] ||
        [k containsString:@"level"] || [k containsString:@"days"]) {
        return 999;
    }
    return %orig;
}
- (double)doubleForKey:(NSString *)key {
    NSString *k = [key lowercaseString];
    if ([k containsString:@"expire"] || [k containsString:@"vip"] || [k containsString:@"time"]) {
        return 9999999999;
    }
    return %orig;
}
%end

// ========== 2. hook NSMutableDictionary JSON ==========
%hook NSMutableDictionary
- (void)setObject:(id)obj forKeyedSubscript:(id)key {
    if ([key isKindOfClass:[NSString class]]) {
        NSString *k = [(NSString *)key lowercaseString];
        if (([k isEqualToString:@"isvip"] || [k isEqualToString:@"is_vip"] ||
             [k isEqualToString:@"vip"] || [k isEqualToString:@"isauthvip"] ||
             [k isEqualToString:@"ismember"]) &&
            [obj isKindOfClass:[NSNumber class]]) {
            obj = @YES;
        }
        if (([k containsString:@"expire"] || [k containsString:@"vipend"] ||
             [k containsString:@"endtime"]) &&
            [obj isKindOfClass:[NSNumber class]]) {
            obj = @9999999999;
        }
    }
    %orig;
}
%end

// ========== 3. 拦截 VIP 弹窗 ==========
%hook UIAlertController
- (void)viewDidAppear:(BOOL)animated {
    NSString *title = [self valueForKey:@"title"];
    NSString *message = [self valueForKey:@"message"];
    if ((title && ([title containsString:@"VIP"] || [title containsString:@"会员"] ||
                   [title containsString:@"开通"] || [title containsString:@"购买"] ||
                   [title containsString:@"过期"] || [title containsString:@"解锁"])) ||
        (message && ([message containsString:@"VIP"] || [message containsString:@"会员"] ||
                     [message containsString:@"开通"] || [message containsString:@"购买"]))) {
        [self dismissViewControllerAnimated:NO completion:nil];
        return;
    }
    %orig;
}
%end

%ctor {
    NSLog(@"[XDTweak] loaded");
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setBool:YES forKey:@"isVip"];
    [defs setBool:YES forKey:@"bAuthVip"];
    [defs setInteger:9999999999 forKey:@"vipExpireTime"];
    [defs setInteger:9999999999 forKey:@"expireTime"];
    [defs synchronize];
}
