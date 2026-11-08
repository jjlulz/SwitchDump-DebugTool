// SwitchDump: debug helper. Copies the structure of UISwitch (on and off) to the clipboard.
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

static void dumpView(UIView *v, int depth, NSMutableString *buf, NSMutableSet *classes) {
    if (depth > 8 || buf.length > 20000) return;
    NSString *pad = [@"" stringByPaddingToLength:(NSUInteger)depth * 2 withString:@" " startingAtIndex:0];
    [classes addObject:NSStringFromClass([v class])];
    [buf appendFormat:@"%@%@ f=%@ a=%.2f hid=%d r=%.1f clip=%d bg=%@ ui=%d\n",
        pad, NSStringFromClass([v class]), NSStringFromCGRect(v.frame), v.alpha, v.hidden,
        v.layer.cornerRadius, v.clipsToBounds, v.backgroundColor ? @"y" : @"n", v.userInteractionEnabled];
    for (UIView *s in v.subviews) dumpView(s, depth + 1, buf, classes);
}

static void dumpLayer(CALayer *l, int depth, NSMutableString *buf) {
    if (depth > 8 || buf.length > 20000) return;
    NSString *pad = [@"" stringByPaddingToLength:(NSUInteger)depth * 2 withString:@" " startingAtIndex:0];
    [buf appendFormat:@"%@%@ f=%@ r=%.1f op=%.2f bg=%d contents=%d\n",
        pad, NSStringFromClass([l class]), NSStringFromCGRect(l.frame), l.cornerRadius,
        l.opacity, l.backgroundColor != NULL, l.contents != nil];
    for (CALayer *s in l.sublayers) dumpLayer(s, depth + 1, buf);
}

static void describeClass(Class c, NSMutableString *buf) {
    Class sup = class_getSuperclass(c);
    [buf appendFormat:@"\n== %s : %s\n", class_getName(c), sup ? class_getName(sup) : "nil"];
    unsigned n = 0;
    Ivar *iv = class_copyIvarList(c, &n);
    for (unsigned i = 0; i < n; i++) {
        const char *enc = ivar_getTypeEncoding(iv[i]);
        [buf appendFormat:@"  ivar %s %s\n", ivar_getName(iv[i]), enc ? enc : ""];
    }
    free(iv);
    Method *m = class_copyMethodList(c, &n);
    for (unsigned i = 0; i < n && i < 60; i++) {
        [buf appendFormat:@"  - %s\n", sel_getName(method_getName(m[i]))];
    }
    free(m);
}

static void toast(UIWindow *w, NSString *text) {
    UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(20, 50, w.bounds.size.width - 40, 34)];
    t.text = text;
    t.textAlignment = NSTextAlignmentCenter;
    t.font = [UIFont boldSystemFontOfSize:14];
    t.textColor = [UIColor whiteColor];
    t.backgroundColor = [UIColor colorWithWhite:0 alpha:0.8];
    t.layer.cornerRadius = 17;
    t.clipsToBounds = YES;
    [w addSubview:t];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [t removeFromSuperview];
    });
}

static NSMutableString *gAll;
static BOOL gDoneOn = NO, gDoneOff = NO;

%hook UISwitch
- (void)didMoveToWindow {
    %orig;
    if (!self.window) return;
    __weak UISwitch *ws = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UISwitch *s = ws;
        if (!s || !s.window) return;
        BOOL on = s.isOn;
        if ((on && gDoneOn) || (!on && gDoneOff)) return;
        if (on) gDoneOn = YES; else gDoneOff = YES;
        if (!gAll) gAll = [NSMutableString string];

        NSMutableString *buf = [NSMutableString string];
        NSMutableSet *classes = [NSMutableSet set];
        [buf appendFormat:@"\n##### UISWITCH %@ in %@ (iOS %@) bounds=%@\n",
            on ? @"ON" : @"OFF", [[NSBundle mainBundle] bundleIdentifier],
            [[UIDevice currentDevice] systemVersion], NSStringFromCGRect(s.bounds)];
        [buf appendFormat:@"onTintColor=%@ tintColor=%@ thumbTintColor=%@\n", s.onTintColor, s.tintColor, s.thumbTintColor];
        [buf appendString:@"\n-- VIEW TREE\n"];
        dumpView(s, 0, buf, classes);
        [buf appendString:@"\n-- LAYER TREE\n"];
        dumpLayer(s.layer, 0, buf);
        [classes addObject:@"UISwitch"];
        for (NSString *name in classes) {
            Class c = NSClassFromString(name);
            if (c && ![name isEqualToString:@"UIView"] && ![name isEqualToString:@"UIImageView"]) describeClass(c, buf);
        }
        [gAll appendString:buf];
        [UIPasteboard generalPasteboard].string = gAll;

        NSString *msg = (gDoneOn && gDoneOff) ? @"SwitchDump: ON + OFF copied. Paste it now."
                                              : [NSString stringWithFormat:@"SwitchDump: %@ copied. Find a switch that is %@.",
                                                 on ? @"ON" : @"OFF", on ? @"OFF" : @"ON"];
        toast(s.window, msg);
    });
}
%end
