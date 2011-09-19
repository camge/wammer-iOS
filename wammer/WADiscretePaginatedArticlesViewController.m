//
//  WADiscretePaginatedArticlesViewController.m
//  wammer-iOS
//
//  Created by Evadne Wu on 8/31/11.
//  Copyright 2011 Iridia Productions. All rights reserved.
//

#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import "WADiscretePaginatedArticlesViewController.h"
#import "IRDiscreteLayoutManager.h"
#import "WADataStore.h"

#import "WAArticleViewController.h"
#import "WAPaginatedArticlesViewController.h"

#import "WAOverlayBezel.h"
#import "CALayer+IRAdditions.h"


static NSString * const kWADiscreteArticlePageElements = @"kWADiscreteArticlePageElements";
static NSString * const kWADiscreteArticleViewControllerOnItem = @"kWADiscreteArticleViewControllerOnItem";
static NSString * const kWADiscreteArticlesViewLastUsedLayoutGrids = @"kWADiscreteArticlesViewLastUsedLayoutGrids";

@interface WADiscretePaginatedArticlesViewController () <IRDiscreteLayoutManagerDelegate, IRDiscreteLayoutManagerDataSource, WAArticleViewControllerPresenting>

@property (nonatomic, readwrite, retain) IRDiscreteLayoutManager *discreteLayoutManager;
@property (nonatomic, readwrite, retain) IRDiscreteLayoutResult *discreteLayoutResult;
@property (nonatomic, readwrite, retain) NSArray *layoutGrids;

- (UIView *) representingViewForItem:(WAArticle *)anArticle;
- (void) adjustPageViewAtIndex:(NSUInteger)anIndex;
- (void) adjustPageViewAtIndex:(NSUInteger)anIndex withAdditionalAdjustments:(void(^)(UIView *aSubview))aBlock;

- (void) adjustPageView:(UIView *)aPageView usingGridAtIndex:(NSUInteger)anIndex;

@end

@implementation WADiscretePaginatedArticlesViewController
@synthesize paginationSlider, discreteLayoutManager, discreteLayoutResult, layoutGrids, paginatedView;

- (id) init {

	return [self initWithNibName:NSStringFromClass([self class]) bundle:[NSBundle bundleForClass:[self class]]];

}

- (void) viewDidLoad {

	[super viewDidLoad];

	if (self.discreteLayoutResult)
		[self.paginatedView reloadViews];
		
	self.paginationSlider.backgroundColor = nil;
	[self.paginationSlider irBind:@"currentPage" toObject:self.paginatedView keyPath:@"currentPage" options:nil];
	
	self.paginatedView.backgroundColor = nil;
	self.paginatedView.frame = UIEdgeInsetsInsetRect(self.paginatedView.frame, (UIEdgeInsets){ 32, 32, 0, 32 });
	self.paginatedView.horizontalSpacing = 32.0f;
	
}

- (UIView *) representingViewForItem:(WAArticle *)anArticle {

	__block __typeof__(self) nrSelf = self;
	__block WAArticleViewController *articleViewController = nil;
	
	articleViewController = objc_getAssociatedObject(anArticle, &kWADiscreteArticleViewControllerOnItem);
	NSURL *objectURI = [[anArticle objectID] URIRepresentation];
	
	if (!articleViewController) {
		articleViewController = [WAArticleViewController controllerForArticle:objectURI usingPresentationStyle:(
			[anArticle.fileOrder count] ? WADiscreteSingleImageArticleStyle :
			[anArticle.previews count] ? WADiscretePreviewArticleStyle : 
			WADiscretePlaintextArticleStyle
		)];
		objc_setAssociatedObject(anArticle, &kWADiscreteArticleViewControllerOnItem, articleViewController, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	
	articleViewController.view.clipsToBounds = YES;
	articleViewController.view.layer.borderColor = [UIColor colorWithWhite:0.9f alpha:1.0f].CGColor;
	articleViewController.view.layer.borderWidth = 1.0f;
	((UIView *)articleViewController.imageStackView).userInteractionEnabled = NO;
	
	articleViewController.onPresentingViewController = ^ (void(^action)(UIViewController <WAArticleViewControllerPresenting> *parentViewController)) {
	
		action(nrSelf);
	
	};
	
	articleViewController.onViewTap = ^ {
	
		[[UIApplication sharedApplication] beginIgnoringInteractionEvents];
	
		WAPaginatedArticlesViewController *paginatedVC = [[[WAPaginatedArticlesViewController alloc] init] autorelease];
		
		paginatedVC.navigationItem.leftBarButtonItem = nil;
		paginatedVC.navigationItem.hidesBackButton = NO;
		
		paginatedVC.context = [NSDictionary dictionaryWithObjectsAndKeys:
			objectURI, @"lastVisitedObjectURI",		
		nil];
		
		paginatedVC.view.clipsToBounds = YES;
		
		UIView *backgroundView = [[[UIView alloc] initWithFrame:[self.navigationController.view convertRect:self.navigationController.topViewController.view.frame fromView:self.navigationController.topViewController.view.superview]] autorelease];
		backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
		backgroundView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5f];
		
		UIView *backingView = [[[UIView alloc] initWithFrame:[self.navigationController.view convertRect:articleViewController.view.frame fromView:articleViewController.view.superview]] autorelease];
		UIView *backingImageHolder = [[[UIView alloc] initWithFrame:backingView.bounds] autorelease];
		backingImageHolder.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
		[backingView addSubview:backingImageHolder];
		
		backingView.backgroundColor = articleViewController.view.backgroundColor;
		backingImageHolder.layer.contents = (id)[articleViewController.view.layer irRenderedImage].CGImage;
		backingImageHolder.layer.contentsGravity = kCAGravityCenter;
		
		[self.navigationController.view addSubview:backgroundView];		
		[self.navigationController.view addSubview:backingView];
		//	backingView.layer.shadowRadius = 4.0f;
		//	backingView.layer.shadowOffset = (CGSize){ 0, 2 };
		//	backingView.layer.shadowOpacity = 0.25f;
		backingView.backgroundColor = [UIColor colorWithWhite:0.97f alpha:1.0f];
		
		backgroundView.alpha = 0;
		
		[UIView animateWithDuration:0.5f delay:0.0f options:UIViewAnimationOptionLayoutSubviews|UIViewAnimationOptionCurveEaseInOut animations: ^ {
			
			backingView.frame = [self.navigationController.view convertRect:self.navigationController.topViewController.view.frame fromView:self.navigationController.topViewController.view.superview];
			backingImageHolder.alpha = 0.0f;
			backgroundView.alpha = 1.0f;
		
		} completion: ^ (BOOL completed) {
		
			backingView.layer.shadowOpacity = 0.0f;
			[backgroundView removeFromSuperview];
		
			[self.navigationController pushViewController:paginatedVC animated:NO];
			
			[UIView animateWithDuration:0.35f animations: ^ {
			
				backingView.alpha = 0.0f;
				
			} completion: ^ (BOOL finished) {
			
				[backingView removeFromSuperview];
				
				[[UIApplication sharedApplication] endIgnoringInteractionEvents];
				
			}];

		}];
	
	};
	
	return articleViewController.view;
	
}

- (void) setContextControlsVisible:(BOOL)contextControlsVisible animated:(BOOL)animated {

	NSLog(@"TBD %s", __PRETTY_FUNCTION__);

}

- (IRDiscreteLayoutGrid *) layoutManager:(IRDiscreteLayoutManager *)manager nextGridForContentsUsingGrid:(IRDiscreteLayoutGrid *)proposedGrid {
	
	NSMutableArray *lastResultantGrids = objc_getAssociatedObject(self, &kWADiscreteArticlesViewLastUsedLayoutGrids);
	
	if (![lastResultantGrids count]) {
		objc_setAssociatedObject(self, &kWADiscreteArticlesViewLastUsedLayoutGrids, nil, OBJC_ASSOCIATION_ASSIGN);
		return proposedGrid;
	}
	
	IRDiscreteLayoutGrid *prototype = [[[lastResultantGrids objectAtIndex:0] retain] autorelease];
	[lastResultantGrids removeObjectAtIndex:0];
	
	return prototype;

}

- (IRDiscreteLayoutManager *) discreteLayoutManager {

	if (discreteLayoutManager)
		return discreteLayoutManager;
		
	__block __typeof__(self) nrSelf = self;
		
	IRDiscreteLayoutGridAreaDisplayBlock genericDisplayBlock = [[^ (IRDiscreteLayoutGrid *self, id anItem) {
	
		if (![anItem isKindOfClass:[WAArticle class]])
			return nil;
	
		return [nrSelf representingViewForItem:(WAArticle *)anItem];
	
	} copy] autorelease];
	
	IRDiscreteLayoutGrid * (^gridWithLayoutBlocks)(IRDiscreteLayoutGridAreaLayoutBlock aBlock, ...) = ^ (IRDiscreteLayoutGridAreaLayoutBlock aBlock, ...) {
	
		IRDiscreteLayoutGrid *returnedPrototype = [IRDiscreteLayoutGrid prototype];
		NSUInteger numberOfAppendedLayoutAreas = 0;
	
		va_list arguments;
		va_start(arguments, aBlock);
		for (IRDiscreteLayoutGridAreaLayoutBlock aLayoutBlock = aBlock; aLayoutBlock != nil; aLayoutBlock =	va_arg(arguments, IRDiscreteLayoutGridAreaLayoutBlock)) {
			[returnedPrototype registerLayoutAreaNamed:[NSString stringWithFormat:@"area_%2.0i", numberOfAppendedLayoutAreas] validatorBlock:nil layoutBlock:aLayoutBlock displayBlock:genericDisplayBlock];
			numberOfAppendedLayoutAreas++;
		};
		va_end(arguments);
		return returnedPrototype;
		
	};
	
	NSMutableArray *enqueuedLayoutGrids = [NSMutableArray array];

	void (^enqueueGridPrototypes)(IRDiscreteLayoutGrid *, IRDiscreteLayoutGrid *) = ^ (IRDiscreteLayoutGrid *aGrid, IRDiscreteLayoutGrid *anotherGrid) {
		aGrid.contentSize = (CGSize){ 768, 1024 };
		anotherGrid.contentSize = (CGSize){ 1024, 768 };
		[enqueuedLayoutGrids addObject:aGrid];		
		[aGrid enumerateLayoutAreaNamesWithBlock: ^ (NSString *anAreaName) {
			[[aGrid class] markAreaNamed:anAreaName inGridPrototype:aGrid asEquivalentToAreaNamed:anAreaName inGridPrototype:anotherGrid];
		}];
	};
	
	IRDiscreteLayoutGridAreaLayoutBlock (^make)(float_t, float_t, float_t, float_t, float_t, float_t) = ^ (float_t a, float_t b, float_t c, float_t d, float_t e, float_t f) { return IRDiscreteLayoutGridAreaLayoutBlockForProportionsMake(a, b, c, d, e, f); };
	
	enqueueGridPrototypes(
		gridWithLayoutBlocks(
			make(2, 3, 0, 0, 1, 1),
			make(2, 3, 0, 1, 1, 1),
			make(2, 3, 1, 0, 1, 2),
			make(2, 3, 0, 2, 2, 1),
		nil),
		gridWithLayoutBlocks(
			make(3, 2, 0, 0, 1, 1),
			make(3, 2, 0, 1, 1, 1),
			make(3, 2, 1, 0, 1, 2),
			make(3, 2, 2, 0, 1, 2),
		nil)
		
	);
	
	enqueueGridPrototypes(
		gridWithLayoutBlocks(
			make(2, 2, 0, 0, 2, 1),
			make(2, 2, 0, 1, 1, 1),
			make(2, 2, 1, 1, 1, 1), 
		nil),
		gridWithLayoutBlocks(
			make(2, 2, 0, 0, 1, 2),
			make(2, 2, 1, 0, 1, 1),
			make(2, 2, 1, 1, 1, 1),
		nil)
	);
	
	enqueueGridPrototypes(
		gridWithLayoutBlocks(
			make(5, 5, 0, 0, 2, 2.5),
			make(5, 5, 0, 2.5, 2, 2.5),
			make(5, 5, 2, 0, 3, 1.66),
			make(5, 5, 2, 1.66, 3, 1.66),
			make(5, 5, 2, 3.32, 3, 1.68), 
		nil),
		gridWithLayoutBlocks(
			make(5, 5, 0, 0, 2, 2.5),
			make(5, 5, 0, 2.5, 2, 2.5),
			make(5, 5, 2, 0, 3, 1.66),
			make(5, 5, 2, 1.66, 3, 1.66),
			make(5, 5, 2, 3.32, 3, 1.68),
		nil)
	);

	enqueueGridPrototypes(
		gridWithLayoutBlocks(
			make(5, 5, 0, 0, 2.5, 3),
			make(5, 5, 0, 3, 2.5, 2),
			make(5, 5, 2.5, 0, 2.5, 1.5),
			make(5, 5, 2.5, 1.5, 2.5, 1.5),
			make(5, 5, 2.5, 3, 2.5, 0.66),
			make(5, 5, 2.5, 3.66, 2.5, 0.66),
			make(5, 5, 2.5, 4.33, 2.5, 0.67), 
		nil),
		gridWithLayoutBlocks(
			make(5, 5, 0, 0, 2, 2),
			make(5, 5, 0, 2, 2, 1),
			make(5, 5, 0, 3, 2, 1),
			make(5, 5, 0, 4, 2, 1),
			make(5, 5, 2, 0, 3, 2),
			make(5, 5, 2, 2, 3, 1.5),
			make(5, 5, 2, 3.5, 3, 1.5),
		nil)
	);

	enqueueGridPrototypes(
		gridWithLayoutBlocks(
			make(3, 3, 0, 0, 3, 1),
			make(3, 3, 0, 1, 1.5, 1),
			make(3, 3, 1.5, 1, 1.5, 1),
			make(3, 3, 0, 2, 1, 1),
			make(3, 3, 1, 2, 1, 1),
			make(3, 3, 2, 2, 1, 1), 
		nil),
		gridWithLayoutBlocks(
			make(3, 3, 0, 0, 1, 3),
			make(3, 3, 1, 0, 1, 1.5),
			make(3, 3, 1, 1.5, 1, 1.5),
			make(3, 3, 2, 0, 1, 1),
			make(3, 3, 2, 1, 1, 1),
			make(3, 3, 2, 2, 1, 1),
		nil)
	);
	
	self.layoutGrids = enqueuedLayoutGrids;
	self.discreteLayoutManager = [[IRDiscreteLayoutManager new] autorelease];
	self.discreteLayoutManager.delegate = self;
	self.discreteLayoutManager.dataSource = self;
	return self.discreteLayoutManager;

}

- (void) viewDidUnload {

	[self.paginationSlider irUnbind:@"currentPage"];

	self.discreteLayoutManager = nil;
	self.discreteLayoutResult = nil;
	[super viewDidUnload];

}

-	(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	
	return YES;
	
}

- (void) reloadViewContents {

	UIScrollView *scrollView = self.paginatedView.scrollView;
	if (scrollView.tracking || scrollView.dragging || scrollView.decelerating) {
		__block __typeof__(self) nrSelf = self;
		dispatch_async(dispatch_get_current_queue(), ^ {
			[nrSelf performSelector:_cmd];
		});
		return;
	};
	
	if (self.discreteLayoutResult) {
		objc_setAssociatedObject(self, &kWADiscreteArticlesViewLastUsedLayoutGrids, [[[self.discreteLayoutResult.grids irMap: ^ (IRDiscreteLayoutGrid *aGridInstance, int index, BOOL *stop) {
			return aGridInstance.prototype;
		}] mutableCopy] autorelease], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	
	self.discreteLayoutResult = [self.discreteLayoutManager calculatedResult];
	objc_setAssociatedObject(self, &kWADiscreteArticlesViewLastUsedLayoutGrids, nil, OBJC_ASSOCIATION_ASSIGN);
		
	NSUInteger lastCurrentPage = self.paginatedView.currentPage;
	
	[self.paginatedView reloadViews];
	self.paginationSlider.numberOfPages = self.paginatedView.numberOfPages;
	
	//	TBD: Cache contents of the previous screen, and then do some page index matching
	//	Instead of going back to the last current page, since we might have nothing left on the current page
	//	And things can get garbled very quickly
	
	if ((self.paginatedView.numberOfPages - 1) >= lastCurrentPage)
		[self.paginatedView scrollToPageAtIndex:lastCurrentPage animated:NO];

}

- (NSUInteger) numberOfItemsForLayoutManager:(IRDiscreteLayoutManager *)manager {

  return [self.fetchedResultsController.fetchedObjects count];

}

- (id<IRDiscreteLayoutItem>) layoutManager:(IRDiscreteLayoutManager *)manager itemAtIndex:(NSUInteger)index {

  return (id<IRDiscreteLayoutItem>)[self.fetchedResultsController.fetchedObjects objectAtIndex:index];

}

- (NSUInteger) numberOfLayoutGridsForLayoutManager:(IRDiscreteLayoutManager *)manager {

  return [self.layoutGrids count];

}

- (id<IRDiscreteLayoutItem>) layoutManager:(IRDiscreteLayoutManager *)manager layoutGridAtIndex:(NSUInteger)index {

  return (id<IRDiscreteLayoutItem>)[self.layoutGrids objectAtIndex:index];

}

- (NSUInteger) numberOfViewsInPaginatedView:(IRPaginatedView *)paginatedView {

	return [self.discreteLayoutResult.grids count];

}

- (UIView *) viewForPaginatedView:(IRPaginatedView *)aPaginatedView atIndex:(NSUInteger)index {

	UIView *returnedView = [[[UIView alloc] initWithFrame:aPaginatedView.bounds] autorelease];
	returnedView.autoresizingMask = UIViewAutoresizingNone;
	returnedView.layer.shouldRasterize = YES;
	
	IRDiscreteLayoutGrid *viewGrid = (IRDiscreteLayoutGrid *)[self.discreteLayoutResult.grids objectAtIndex:index];
	
	NSMutableArray *pageElements = [NSMutableArray arrayWithCapacity:[viewGrid.layoutAreaNames count]];
	
	CGSize oldContentSize = viewGrid.contentSize;
	viewGrid.contentSize = aPaginatedView.frame.size;
	
	[viewGrid enumerateLayoutAreasWithBlock: ^ (NSString *name, id item, BOOL(^validatorBlock)(IRDiscreteLayoutGrid *self, id anItem), CGRect(^layoutBlock)(IRDiscreteLayoutGrid *self, id anItem), id(^displayBlock)(IRDiscreteLayoutGrid *self, id anItem)) {
	
		if (!item)
			return;
	
		UIView *placedSubview = (UIView *)displayBlock(viewGrid, item);
		NSParameterAssert(placedSubview);
		placedSubview.frame = layoutBlock(viewGrid, item);
		[pageElements addObject:placedSubview];
		[returnedView addSubview:placedSubview];
				
	}];

	viewGrid.contentSize = oldContentSize;
	
	objc_setAssociatedObject(returnedView, &kWADiscreteArticlePageElements, pageElements, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	
	[returnedView setNeedsLayout];
	
	[self adjustPageView:returnedView usingGridAtIndex:index];
			
	return returnedView;

}

- (UIViewController *) viewControllerForSubviewAtIndex:(NSUInteger)index inPaginatedView:(IRPaginatedView *)paginatedView {

	return nil;

}

- (void) adjustPageViewAtIndex:(NSUInteger)anIndex {

	[self adjustPageViewAtIndex:anIndex withAdditionalAdjustments:nil];

}

- (void) adjustPageView:(UIView *)currentPageView usingGridAtIndex:(NSUInteger)anIndex {

	//	Find the best grid alternative in allDestinations, and then enumerate its layout areas, using the provided layout blocks to relayout all the element representing views in the current paginated view page.
	
	if ([self.discreteLayoutResult.grids count] < (anIndex + 1))
		return;
	
	NSArray *currentPageElements = objc_getAssociatedObject(currentPageView, &kWADiscreteArticlePageElements);
	IRDiscreteLayoutGrid *currentPageGrid = [self.discreteLayoutResult.grids objectAtIndex:anIndex];
	NSSet *allDestinations = [currentPageGrid allTransformablePrototypeDestinations];
	NSSet *allIntrospectedGrids = [allDestinations setByAddingObject:currentPageGrid];
	IRDiscreteLayoutGrid *bestGrid = nil;
	CGFloat currentAspectRatio = CGRectGetWidth(self.paginatedView.frame) / CGRectGetHeight(self.paginatedView.frame);
	for (IRDiscreteLayoutGrid *aGrid in allIntrospectedGrids) {
		
		CGFloat bestGridAspectRatio = bestGrid.contentSize.width / bestGrid.contentSize.height;
		CGFloat currentGridAspectRatio = aGrid.contentSize.width / aGrid.contentSize.height;
		
		if (!bestGrid) {
			bestGrid = [[aGrid retain] autorelease];
			continue;
		}
		
		if (fabs(currentAspectRatio - bestGridAspectRatio) < fabs(currentAspectRatio - currentGridAspectRatio)) {
			continue;
		}
		
		bestGrid = [[aGrid retain] autorelease];
		
	}
	
	
	IRDiscreteLayoutGrid *transformedGrid = bestGrid;//[allDestinations anyObject];
	transformedGrid = [currentPageGrid transformedGridWithPrototype:(transformedGrid.prototype ? transformedGrid.prototype : transformedGrid)];
	
	CGSize oldContentSize = transformedGrid.contentSize;
	transformedGrid.contentSize = self.paginatedView.frame.size;
	[[currentPageGrid retain] autorelease];
			
	[transformedGrid enumerateLayoutAreasWithBlock: ^ (NSString *name, id item, BOOL(^validatorBlock)(IRDiscreteLayoutGrid *self, id anItem), CGRect(^layoutBlock)(IRDiscreteLayoutGrid *self, id anItem), id(^displayBlock)(IRDiscreteLayoutGrid *self, id anItem)) {
	
		if (!item)
			return;
	
		((UIView *)[currentPageElements objectAtIndex:[currentPageGrid.layoutAreaNames indexOfObject:name]]).frame = layoutBlock(transformedGrid, item);
		
	}];
	
	transformedGrid.contentSize = oldContentSize;

}

- (void) adjustPageViewAtIndex:(NSUInteger)anIndex withAdditionalAdjustments:(void(^)(UIView *aSubview))aBlock {

	UIView *currentPageView = [self.paginatedView existingPageAtIndex:anIndex];	
	[self adjustPageView:currentPageView usingGridAtIndex:anIndex];
		
	if (aBlock)
		aBlock(currentPageView);

}

- (void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {

	[super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
	
	void (^removeAnimations)(UIView *) = ^ (UIView *introspectedView) {
	
		__block void (^removeAnimationsOnView)(UIView *aView) = nil;
		
		removeAnimationsOnView = ^ (UIView *aView) {
		
			[aView.layer removeAllAnimations];

			for (UIView *aSubview in aView.subviews)
				removeAnimationsOnView(aSubview);
		
		};
		
		removeAnimationsOnView(introspectedView);

	};
	
	[CATransaction begin];
	[CATransaction setDisableActions:YES];
	
	removeAnimations(self.paginatedView);

	//	If the paginated view is currently showing a view constructed with information provided by a layout grid, and that layout grid’s prototype has a fully transformable target, grab that transformable prototype and do a transform, then reposition individual items
	
	if (self.paginatedView.currentPage > 0)
		[self adjustPageViewAtIndex:(self.paginatedView.currentPage - 1) withAdditionalAdjustments:removeAnimations];
	
	[self adjustPageViewAtIndex:self.paginatedView.currentPage withAdditionalAdjustments:removeAnimations];
	
	if ((self.paginatedView.currentPage + 1) < self.paginatedView.numberOfPages) {
		[self adjustPageViewAtIndex:(self.paginatedView.currentPage + 1) withAdditionalAdjustments:removeAnimations];
	}
	
	[CATransaction commit];
	
}

- (void) paginationSlider:(WAPaginationSlider *)slider didMoveToPage:(NSUInteger)destinationPage {

	if (self.paginatedView.currentPage == destinationPage)
		return;
	
	[[UIApplication sharedApplication] beginIgnoringInteractionEvents];
	
	dispatch_async(dispatch_get_main_queue(), ^ {
	
		[CATransaction begin];
		CATransition *transition = [CATransition animation];
		transition.type = kCATransitionMoveIn;
		transition.subtype = (self.paginatedView.currentPage < destinationPage) ? kCATransitionFromRight : kCATransitionFromLeft;
		transition.duration = 0.25f;
		transition.fillMode = kCAFillModeForwards;
		transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
		transition.removedOnCompletion = YES;
		
		[self.paginatedView scrollToPageAtIndex:destinationPage animated:NO];
		[(id<UIScrollViewDelegate>)self.paginatedView scrollViewDidScroll:self.paginatedView.scrollView];
		[self.paginatedView.layer addAnimation:transition forKey:@"transition"];
		
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, transition.duration * NSEC_PER_SEC), dispatch_get_main_queue(), ^ {
			[[UIApplication sharedApplication] endIgnoringInteractionEvents];
		});
		
		[CATransaction commit];
	
	});
	
}

- (void) dealloc {

	[self.paginationSlider irUnbind:@"currentPage"];
	
	[paginationSlider release];
	[paginatedView release];
	[discreteLayoutManager release];
	[discreteLayoutResult release];
	[layoutGrids release];

	[super dealloc];

}

@end
