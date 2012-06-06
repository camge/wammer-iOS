//
//  WAOverviewController+ContextPresenting.m
//  wammer
//
//  Created by Evadne Wu on 2/29/12.
//  Copyright (c) 2012 Waveface. All rights reserved.
//

#import "WAOverviewController+ContextPresenting.h"
#import "WAArticleViewController.h"
#import "WADataStore.h"
#import "WAFauxRootNavigationController.h"
#import "WANavigationBar.h"
#import "WAButton.h"
#import "WAGestureWindow.h"
#import "IRTransparentToolbar.h"
#import "WAStackedArticleViewController.h"

NSString * const kPresentedArticle = @"WAOverviewController_presentedArticle";


@interface WAOverviewController (ContextPresenting_Private)

- (void(^)(void)) dismissBlockForArticleContextViewController:(WAArticleViewController *)controller;
- (void) setDismissBlock:(void(^)(void))aBlock forArticleContextViewController:(WAArticleViewController *)controller;

@end


@implementation WAOverviewController (ContextPresenting)

- (WAArticle *) presentedArticle {

	return [self irAssociatedObjectWithKey:&kPresentedArticle];

}

- (void) setPresentedArticle:(WAArticle *)presentedArticle {

	[self irAssociateObject:presentedArticle usingKey:&kPresentedArticle policy:OBJC_ASSOCIATION_RETAIN_NONATOMIC changingObservedKey:nil];
	
}

- (WAArticleViewController *) presentDetailedContextForArticle:(WAArticle *)article {
	
	[[UIApplication sharedApplication] beginIgnoringInteractionEvents];
	
	__weak WAOverviewController *wSelf = self;
	
	self.presentedArticle = article;
	
	WAArticleViewController *shownArticleVC = [self newContextViewControllerForArticle:article];
	shownArticleVC.hostingViewController = self;
	
	UINavigationController *enqueuedNavController = [self wrappingNavigationControllerForContextViewController:shownArticleVC];
	
	UIWindow * const containingWindow = self.navigationController.view.window;
	CGAffineTransform const containingWindowTransform = containingWindow.rootViewController.view.transform;
	CGRect const containingWindowBounds = CGRectApplyAffineTransform(containingWindow.bounds, containingWindowTransform);
	
	UIView *containerView = [[UIView alloc] initWithFrame:containingWindowBounds];
	containerView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
	containerView.center = irCGRectAnchor(containingWindow.bounds, irCenter, YES);
	containerView.transform = containingWindowTransform;
	
	UIWindow *currentKeyWindow = [UIApplication sharedApplication].keyWindow;
	UIColor *backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
			
	UIScreen *usedScreen = [UIApplication sharedApplication].keyWindow.screen;
	if (!usedScreen)
		usedScreen = [UIScreen mainScreen];
	
	__block WAGestureWindow *containerWindow = [[WAGestureWindow alloc] initWithFrame:usedScreen.bounds];
	containerWindow.backgroundColor = backgroundColor;
	containerWindow.opaque = NO;
	containerWindow.rootViewController = enqueuedNavController;
	
	containerWindow.onTap = ^ {
		
		[wSelf dismissArticleContextViewController:shownArticleVC];
		containerWindow.onTap = nil;
		
	};
			
	containerWindow.onGestureRecognizeShouldReceiveTouch = ^ (UIGestureRecognizer *recognizer, UITouch *touch) {
	
		if (shownArticleVC.modalViewController)
			return NO;
		
		UINavigationController *navC = shownArticleVC.navigationController;
		
		if (navC) {
		
			if (navC.modalViewController)
				return NO;
		
			if (!navC.navigationBarHidden)
			if (CGRectContainsPoint(navC.navigationBar.bounds, [touch locationInView:navC.navigationBar]))
				return NO;
			
			if (!navC.toolbarHidden)
			if (CGRectContainsPoint(navC.toolbar.bounds, [touch locationInView:navC.toolbar]))
				return NO;
		
		}
		
		CGPoint locationInShownArticleVC = [touch locationInView:shownArticleVC.view];
		
		if ([shownArticleVC isKindOfClass:[WAStackedArticleViewController class]])
			return (BOOL)![(WAStackedArticleViewController *)shownArticleVC isPointInsideInterfaceRect:locationInShownArticleVC];
		
		return NO;
	
	};
	
	[enqueuedNavController setNavigationBarHidden:YES animated:NO];
	
	__weak UINavigationController *nrEnqueuedNavController = enqueuedNavController;
	__weak WAStackedArticleViewController *shownStackedArticleVC = [shownArticleVC isKindOfClass:[WAStackedArticleViewController class]] ? (WAStackedArticleViewController *)shownArticleVC : nil;

	shownStackedArticleVC.onViewDidLoad = ^ (WAArticleViewController *self, UIView *ownView) {
	
		IRCATransact(^{
		
			shownArticleVC.view.backgroundColor = [UIColor clearColor];
			[nrEnqueuedNavController.view layoutSubviews];
			
			[shownStackedArticleVC handlePreferredInterfaceRect:shownArticleVC.view.bounds];
			
			__block void (^poke)(UIView *) = ^ (UIView *aView) {
			
				[aView layoutSubviews];
				
				for (UIView *aSubview in aView.subviews)
					poke(aSubview);
				
			};
			
			poke(shownArticleVC.view);
			poke = nil;
		
		});							
	
	};
	
	if ([shownStackedArticleVC isViewLoaded])
		shownStackedArticleVC.onViewDidLoad(shownStackedArticleVC, shownStackedArticleVC.view);
	
	shownStackedArticleVC.onPullTop = ^ (UIScrollView *aSV) {
		
		[aSV setContentOffset:aSV.contentOffset animated:NO];
		[wSelf dismissArticleContextViewController:shownArticleVC];
		
	};
	
	shownStackedArticleVC.headerView = ((^ {
		
		IRView *enclosingView = [[IRView alloc] initWithFrame:(CGRect){ CGPointZero, (CGSize){ 64, 64 }}];
		
		enclosingView.opaque = NO;
								
		CGRect toolbarRect = UIEdgeInsetsInsetRect(enclosingView.bounds, (UIEdgeInsets){ 0, 28, 0, 0 });
		toolbarRect.size.height = 44;
		
		UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:toolbarRect];
		[enclosingView addSubview:toolbar];
		
		toolbar.backgroundColor = [UIColor colorWithWhite:245.0/255.0 alpha:1];
		
		UIImage *toolbarBackground = [[UIImage imageNamed:@"WAArticleStackHeaderBarBackground"] resizableImageWithCapInsets:UIEdgeInsetsZero];
		UIImage *toolbarBackgroundLandscapePhone = [[UIImage imageNamed:@"WAArticleStackHeaderBarBackgroundLandscapePhone"] resizableImageWithCapInsets:UIEdgeInsetsZero];
		
		NSCParameterAssert(toolbarBackground);
		NSCParameterAssert(toolbarBackgroundLandscapePhone);
		
		[toolbar setBackgroundImage:toolbarBackground forToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsDefault];
		[toolbar setBackgroundImage:toolbarBackgroundLandscapePhone forToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsLandscapePhone];
						
		toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleBottomMargin;
		toolbar.items = shownStackedArticleVC.headerBarButtonItems;
		
		enclosingView.onLayoutSubviews = ^ {
		
			[toolbar layoutSubviews];
		
		};
		
		__block WAButton *nrCloseButton = [WAButton buttonWithType:UIButtonTypeCustom];
		[enclosingView addSubview:nrCloseButton];
		[nrCloseButton setImage:[UIImage imageNamed:@"WACornerCloseButton"] forState:UIControlStateNormal];
		[nrCloseButton setImage:[UIImage imageNamed:@"WACornerCloseButtonActive"] forState:UIControlStateHighlighted];
		[nrCloseButton setImage:[UIImage imageNamed:@"WACornerCloseButtonActive"] forState:UIControlStateSelected];
		nrCloseButton.frame = enclosingView.bounds;
		nrCloseButton.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin|UIViewAutoresizingFlexibleRightMargin;
		nrCloseButton.action = ^ {
		
			[wSelf dismissArticleContextViewController:shownArticleVC];
			nrCloseButton.action = nil;
		
		};
		
		return enclosingView;
									
	})());
	
	[[UIApplication sharedApplication] endIgnoringInteractionEvents];
	
	[CATransaction begin];
	
	[containerWindow makeKeyAndVisible];
	
	UIViewAnimationOptions animationOptions = UIViewAnimationOptionCurveEaseInOut;
	
	UIView *rootView = containerWindow.rootViewController.view;
	CGRect toFrame = rootView.frame;
	CGRect fromFrame = rootView.frame = [rootView.superview convertRect:CGRectOffset(rootView.bounds, 0, CGRectGetHeight(rootView.bounds)) fromView:rootView];
	
	UIColor *fromBackgroundColor = [UIColor clearColor];
	UIColor *toBackgroundColor = containerWindow.backgroundColor;
					
	containerWindow.backgroundColor = fromBackgroundColor;
	containerWindow.rootViewController.view.frame = fromFrame;
	
	[UIView animateWithDuration:0.35 delay:0 options:animationOptions animations:^{
	
		containerWindow.backgroundColor = toBackgroundColor;
		containerWindow.rootViewController.view.frame = toFrame;
	
	} completion:nil];
	
	[CATransaction commit];
				
	void (^dismissBlock)(void) = ^ {
			
		UIView *rootView = containerWindow.rootViewController.view;
		NSParameterAssert(rootView);
		
		UIViewAnimationOptions animationOptions = UIViewAnimationOptionCurveEaseInOut;
		
		[UIView animateWithDuration:0.35 delay:0 options:animationOptions animations:^{
		
			rootView.frame = [rootView.superview convertRect:CGRectOffset(rootView.bounds, 0, CGRectGetHeight(rootView.bounds)) fromView:rootView];
			containerWindow.backgroundColor = nil;
			
		} completion:^(BOOL finished) {
		
			@autoreleasepool {
					
				containerWindow.rootViewController = nil;
				
			}
		
			containerWindow.hidden = YES;
			containerWindow.userInteractionEnabled = NO;
			
			[containerWindow resignKeyWindow];
			containerWindow = nil;
			
			//	Potentially smoofy
			
			NSArray *allCurrentWindows = [UIApplication sharedApplication].windows;
			__block BOOL hasFoundCapturedKeyWindow = NO;
			
			[allCurrentWindows enumerateObjectsUsingBlock: ^ (UIWindow *aWindow, NSUInteger idx, BOOL *stop) {
			
				if (aWindow == currentKeyWindow) {
					[aWindow makeKeyAndVisible];
					hasFoundCapturedKeyWindow = YES;
					*stop = YES;
					return;
				}
				
				if (!hasFoundCapturedKeyWindow)
				if (idx == ([allCurrentWindows count] - 1))
					[[allCurrentWindows objectAtIndex:0] becomeKeyWindow];
				
			}];
			
		}];
	
	};
	
	[self setDismissBlock:dismissBlock forArticleContextViewController:shownArticleVC];
	
	return shownArticleVC;
	
}

- (void) dismissArticleContextViewController:(WAArticleViewController *)controller {

	self.presentedArticle = nil;

	[[UIApplication sharedApplication] beginIgnoringInteractionEvents];
	
	(([self dismissBlockForArticleContextViewController:controller])());
	[self setDismissBlock:nil forArticleContextViewController:controller];
	
	[[UIApplication sharedApplication] endIgnoringInteractionEvents];

}

- (WAArticleViewController *) newContextViewControllerForArticle:(WAArticle *)article {

	__weak WAOverviewController *wSelf = self;
	
	WAArticleStyle style = WAFullScreenArticleStyle|WASuggestedStyleForArticle(article);
	WAArticleViewController *returnedVC	= [WAArticleViewController controllerForArticle:article style:style];
	
	returnedVC.hostingViewController = self;
	
	UINavigationItem *navItem = returnedVC.navigationItem;
	
	if (!navItem.leftBarButtonItem) {
		
		navItem.hidesBackButton = NO;
		navItem.leftBarButtonItem = WABackBarButtonItem(nil, @"Back", ^ {

			[wSelf dismissArticleContextViewController:returnedVC];

		});
	
	}

	return returnedVC;

}

- (UINavigationController *) wrappingNavigationControllerForContextViewController:(WAArticleViewController *)controller {
	
	WANavigationController *returnedNavC = nil;
	
	if ([controller isKindOfClass:[WAArticleViewController class]]) {
	
		returnedNavC = [[WANavigationController alloc] initWithRootViewController:controller];
		
	} else {

		returnedNavC = [[WAFauxRootNavigationController alloc] initWithRootViewController:controller];
		
	}
	
	returnedNavC.onViewDidLoad = ^ (WANavigationController *self) {
		((WANavigationBar *)self.navigationBar).customBackgroundView = [WANavigationBar defaultPatternBackgroundView];
	};
	
	if ([returnedNavC isViewLoaded])
	if (returnedNavC.onViewDidLoad)
		returnedNavC.onViewDidLoad(returnedNavC);
	
	return returnedNavC;

}

@end


@implementation WAOverviewController (ContextPresenting_Private)

NSString * const kWAOverviewController_ContextPresenting_Private_DismissBlock = @"WAOverviewController_ContextPresenting_Private_DismissBlock";

- (void(^)(void)) dismissBlockForArticleContextViewController:(WAArticleViewController *)controller {

	return objc_getAssociatedObject(controller, &kWAOverviewController_ContextPresenting_Private_DismissBlock);

}

- (void) setDismissBlock:(void(^)(void))aBlock forArticleContextViewController:(WAArticleViewController *)controller {

	if (aBlock == [self dismissBlockForArticleContextViewController:controller])
		return;

	objc_setAssociatedObject(controller, &kWAOverviewController_ContextPresenting_Private_DismissBlock, aBlock, OBJC_ASSOCIATION_COPY_NONATOMIC);

}

@end
