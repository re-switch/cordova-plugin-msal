//
//  AppDelegate+MsalCallback.h
//  KSUMobile
//
//  Created by wrobins on 12/6/19.
//

#import "AppDelegate.h"
#import <UIKit/UIKit.h>

@interface AppDelegate (MsalCallback) <UISceneDelegate>

- (BOOL)application:(UIApplication *)app
            openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options;

- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts;

@end

/* AppDelegate_MsalCallback_h */
