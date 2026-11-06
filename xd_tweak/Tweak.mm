#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL isVIPKey(NSString *key) {
    NSString *k = [key lowercaseString];
    return [k containsString:@"vip"] || [k containsString:@"member"] ||
           [k containsString:@"auth"] || [k containsString:@"paid"] ||
           [k containsString:@"unlock"] || [k containsString:@"purchas"];
}

static BOOL (*orig_boolForKey)(id, SEL, NSString*);
static BOOL hook_boolForKey(id self, SEL _cmd, NSString *key) {
    if (isVIPKey(key)) return YES;
    return orig_boolForKey(self, _cmd, key);
}

static id (*orig_objectForKey)(id, SEL, NSString*);
static id hook_objectForKey(id self, SEL _cmd, NSString *key) {
    if (isVIPKey(key)) {
        if ([[key lowercaseString] containsString:@"expire"] ||
            [[key lowercaseString] containsString:@"time"] ||
            [[key lowercaseString] containsString:@"date"]) {
            return @9999999999;
        }
        return @YES;
    }
    return orig_objectForKey(self, _cmd, key);
}

static NSInteger (*orig_integerForKey)(id, SEL, NSString*);
static NSInteger hook_integerForKey(id self, SEL _cmd, NSString *key) {
    if (isVIPKey(key)) return 999;
    return orig_integerForKey(self, _cmd, key);
}

static double (*orig_doubleForKey)(id, SEL, NSString*);
static double hook_doubleForKey(id self, SEL _cmd, NSString *key) {
    if (isVIPKey(key) || [[key lowercaseString] containsString:@"expire"]) return 9999999999;
    return orig_doubleForKey(self, _cmd, key);
}

static void (*orig_setObjectSub)(id, SEL, id, id<NSCopying>);
static void hook_setObjectSub(id self, SEL _cmd, id obj, id<NSCopying> key) {
    if ([key isKindOfClass:[NSString class]]) {
        NSString *k = [(NSString *)key lowercaseString];
        if (([k isEqualToString:@"isvip"] || [k isEqualToString:@"is_vip"] ||
             [k isEqualToString:@"vip"] || [k isEqualToString:@"isauthvip"] ||
             [k isEqualToString:@"ismember"]) &&
            [obj isKindOfClass:[NSNumber class]]) {
            obj = @YES;
        }
        if (([k containsString:@"expire"] || [k containsString:@"endtime"]) &&
            [obj isKindOfClass:[NSNumber class]]) {
            obj = @9999999999;
        }
    }
    orig_setObjectSub(self, _cmd, obj, key);
}

static void swizzle(Class cls, SEL sel, IMP newImp, IMP *origImp) {
    Method m = class_getInstanceMethod(cls, sel);
    if (m) {
        *origImp = method_setImplementation(m, newImp);
        NSLog(@"[XDTweak] hooked %@ %@", NSStringFromClass(cls), NSStringFromSelector(sel));
    }
}

__attribute__((constructor)) static void XDTweakInit() {
    @autoreleasepool {
        NSLog(@"[XDTweak] === loaded ===");
        Class ud = objc_getClass("NSUserDefaults");
        swizzle(ud, @selector(boolForKey:), (IMP)hook_boolForKey, (IMP*)&orig_boolForKey);
        swizzle(ud, @selector(objectForKey:), (IMP)hook_objectForKey, (IMP*)&orig_objectForKey);
        swizzle(ud, @selector(integerForKey:), (IMP)hook_integerForKey, (IMP*)&orig_integerForKey);
        swizzle(ud, @selector(doubleForKey:), (IMP)hook_doubleForKey, (IMP*)&orig_doubleForKey);

        Class md = objc_getClass("NSMutableDictionary");
        swizzle(md, @selector(setObject:forKeyedSubscript:), (IMP)hook_setObjectSub, (IMP*)&orig_setObjectSub);

        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        [defs setBool:YES forKey:@"isVip"];
        [defs setBool:YES forKey:@"bAuthVip"];
        [defs setInteger:9999999999 forKey:@"vipExpireTime"];
        [defs setInteger:9999999999 forKey:@"expireTime"];
        [defs synchronize];
        NSLog(@"[XDTweak] done");
    }
}
