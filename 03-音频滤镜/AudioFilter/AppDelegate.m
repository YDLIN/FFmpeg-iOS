//
//  AppDelegate.m
//  Encode&Decode
//
//  Created by Du on 2022/2/19.
//

#import "AppDelegate.h"
#import <libavformat/avformat.h>
#import <libavdevice/avdevice.h>
#import <libavcodec/avcodec.h>
#import <libavutil/avutil.h>
#include <libavfilter/avfilter.h>

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    // 初始化libavdevice并注册所有输入和输出设备
//    NSLog(@"----注册设备");
    av_register_all();
    avcodec_register_all();
    avdevice_register_all();
    return YES;
}


#pragma mark - UISceneSession lifecycle


- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options {
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
}


- (void)application:(UIApplication *)application didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions {
    // Called when the user discards a scene session.
    // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
    // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
}


@end
