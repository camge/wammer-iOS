//
//  WAAppDelegate_iOS.h
//  wammer
//
//  Created by Evadne Wu on 12/17/11.
//  Copyright (c) 2011 Waveface. All rights reserved.
//

#import "WAAppDelegate.h"
#import "WACacheManager.h"
#import "WASyncManager.h"
#import "WAPhotoImportManager.h"
#import "WASlidingMenuViewController.h"
#import "GAI.h"

@interface WAAppDelegate_iOS : WAAppDelegate <UIApplicationDelegate, UIAlertViewDelegate>

@property (nonatomic, readwrite, retain) UIWindow *window;
@property (nonatomic, retain) id<GAITracker> tracker;
@property (nonatomic, readonly, strong) WAPhotoImportManager *photoImportManager;
@property (nonatomic, readonly, strong) WACacheManager *cacheManager;
@property (nonatomic, readonly, strong) WASyncManager *syncManager;
@property (nonatomic, readonly, strong) WASlidingMenuViewController *slidingMenu;

- (void) recreateViewHierarchy;

@end
