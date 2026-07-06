//
//  AppDelegate+MsalCallback.m
//  KSUMobile
//
//  Created by wrobins on 12/6/19.
//

#import "AppDelegate+MsalCallback.h"
#import <MSAL/MSAL.h>
#import <objc/runtime.h>

#pragma mark - Scene Delegate Swizzling (iPadOS 13+, required on iPadOS 26+)

// Handler that MSAL needs to receive the callback URL after auth
static void MsalPlugin_handleURLContexts(NSSet<UIOpenURLContext *> *URLContexts)
{
    for (UIOpenURLContext *context in URLContexts) {
        NSLog(@"[MsalPlugin] scene:openURLContexts: received URL=%@ source=%@",
              context.URL, context.options.sourceApplication);
        BOOL handled = [MSALPublicClientApplication handleMSALResponse:context.URL
                                                     sourceApplication:context.options.sourceApplication];
        NSLog(@"[MsalPlugin] MSAL handleMSALResponse returned %@", handled ? @"YES" : @"NO");
    }
}

// Our swizzled implementation
static void MsalPlugin_scene_openURLContexts(id self, SEL _cmd, UIScene *scene, NSSet<UIOpenURLContext *> *URLContexts)
{
    MsalPlugin_handleURLContexts(URLContexts);

    // Call original implementation if it existed
    SEL originalSelector = NSSelectorFromString(@"msal_original_scene:openURLContexts:");
    if ([self respondsToSelector:originalSelector]) {
        IMP originalIMP = [self methodForSelector:originalSelector];
        void (*originalFunc)(id, SEL, UIScene *, NSSet<UIOpenURLContext *> *) = (void *)originalIMP;
        originalFunc(self, originalSelector, scene, URLContexts);
    }
}

// Install the swizzle on any class that becomes a scene delegate
static void MsalPlugin_installSceneDelegateSwizzle(Class sceneDelegateClass)
{
    static NSMutableSet *swizzledClasses = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        swizzledClasses = [NSMutableSet new];
    });

    @synchronized (swizzledClasses) {
        NSString *className = NSStringFromClass(sceneDelegateClass);
        if ([swizzledClasses containsObject:className]) {
            return;
        }
        [swizzledClasses addObject:className];

        SEL selector = @selector(scene:openURLContexts:);
        Method existingMethod = class_getInstanceMethod(sceneDelegateClass, selector);

        if (existingMethod) {
            SEL renamedSelector = NSSelectorFromString(@"msal_original_scene:openURLContexts:");
            class_addMethod(sceneDelegateClass,
                            renamedSelector,
                            method_getImplementation(existingMethod),
                            method_getTypeEncoding(existingMethod));
            method_setImplementation(existingMethod, (IMP)MsalPlugin_scene_openURLContexts);
            NSLog(@"[MsalPlugin] Swizzled existing scene:openURLContexts: on %@", className);
        } else {
            class_addMethod(sceneDelegateClass,
                            selector,
                            (IMP)MsalPlugin_scene_openURLContexts,
                            "v@:@@");
            NSLog(@"[MsalPlugin] Added scene:openURLContexts: to %@", className);
        }
    }
}

@implementation AppDelegate (MsalCallback)

+ (void)load
{
    [[NSNotificationCenter defaultCenter] addObserverForName:UISceneWillConnectNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        UIScene *scene = note.object;
        id delegate = scene.delegate;
        if (delegate) {
            MsalPlugin_installSceneDelegateSwizzle([delegate class]);
        } else {
            NSLog(@"[MsalPlugin] Scene has no delegate at UISceneWillConnectNotification");
        }
    }];

    dispatch_async(dispatch_get_main_queue(), ^{
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            id delegate = scene.delegate;
            if (delegate) {
                MsalPlugin_installSceneDelegateSwizzle([delegate class]);
            }
        }
    });
}

- (BOOL)application:(UIApplication *)app
            openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options
{
    NSLog(@"[MsalPlugin] application:openURL: received URL=%@", url);
    BOOL handled = [MSALPublicClientApplication handleMSALResponse:url
                                                 sourceApplication:options[UIApplicationOpenURLOptionsSourceApplicationKey]];
    NSLog(@"[MsalPlugin] MSAL handleMSALResponse returned %@", handled ? @"YES" : @"NO");
    return handled;
}

// Note: scene:openURLContexts: on AppDelegate is NEVER called by the system.
// The real handler is installed via swizzling on the actual UISceneDelegate class above.

@end
