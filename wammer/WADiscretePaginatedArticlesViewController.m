//
//  WADiscretePaginatedArticlesViewController.m
//  wammer-iOS
//
//  Created by Evadne Wu on 8/31/11.
//  Copyright 2011 Waveface Inc. All rights reserved.
//

#import <math.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

#import "WADiscretePaginatedArticlesViewController.h"
#import "IRDiscreteLayout.h"

#import "WADataStore.h"
#import "WAArticleViewController.h"
#import "WAPaginatedArticlesViewController.h"
#import "WAOverlayBezel.h"

#import "UIKit+IRAdditions.h"
#import "CALayer+IRAdditions.h"

#import "WAFauxRootNavigationController.h"
#import "WANavigationBar.h"

#import "WARemoteInterface.h"
#import "WADataStore.h"
#import "WAArticle+WARemoteInterfaceEntitySyncing.h"

#import "WAViewController.h"
#import "WAGestureWindow.h"
#import "WAButton.h"


static NSString * const kWADiscreteArticlePageElements = @"kWADiscreteArticlePageElements";


@interface WADiscretePaginatedArticlesViewController () <IRDiscreteLayoutManagerDelegate, IRDiscreteLayoutManagerDataSource, WAArticleViewControllerPresenting, UIGestureRecognizerDelegate, WAPaginationSliderDelegate>

- (void) handleApplicationDidBecomeActive:(NSNotification *)aNotification;
- (void) handleApplicationDidEnterBackground:(NSNotification *)aNotification;

@property (nonatomic, readwrite, retain) IRDiscreteLayoutManager *discreteLayoutManager;
@property (nonatomic, readwrite, retain) IRDiscreteLayoutResult *discreteLayoutResult;
@property (nonatomic, readwrite, retain) NSArray *layoutGrids;
@property (nonatomic, readwrite, assign) BOOL requiresRecalculationOnFetchedResultsChangeEnd;

- (void) adjustPageViewAtIndex:(NSUInteger)anIndex;
- (void) adjustPageView:(UIView *)aPageView usingGridAtIndex:(NSUInteger)anIndex;

@end


@implementation WADiscretePaginatedArticlesViewController
@synthesize paginationSliderSlot;
@synthesize paginationSlider, discreteLayoutManager, discreteLayoutResult, layoutGrids, paginatedView;
@synthesize requiresRecalculationOnFetchedResultsChangeEnd;

- (id) init {

	self = [self initWithNibName:NSStringFromClass([self class]) bundle:[NSBundle bundleForClass:[self class]]];
	if (!self)
		return nil;
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleApplicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleApplicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
	
	return self;

}

- (void) handleApplicationDidBecomeActive:(NSNotification *)aNotification {

	[[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(performReadingProgressSync) object:nil];
	[self performSelector:@selector(performReadingProgressSync) withObject:nil afterDelay:1];

}

- (void) handleApplicationDidEnterBackground:(NSNotification *)aNotification {

	if (![self isViewLoaded])
		return;
		
	NSArray *allGrids = self.discreteLayoutResult.grids;
	if (![allGrids count])
		return;

	IRDiscreteLayoutGrid *grid = [allGrids objectAtIndex:self.paginatedView.currentPage];
	
	NSString *lastArticleID = ((WAArticle *)[grid layoutItemForAreaNamed:[grid.layoutAreaNames lastObject]]).identifier;
	if (!lastArticleID)
		return;
	
	__block UIBackgroundTaskIdentifier taskID = UIBackgroundTaskInvalid;
	taskID = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];
	[self updateLatestReadingProgressWithIdentifier:lastArticleID completion:^(BOOL didUpdate) {
		[[UIApplication sharedApplication] endBackgroundTask:taskID];
	}];
	
}

- (void) viewDidLayoutSubviews {

	[super viewDidLayoutSubviews];
	
	if (!self.paginatedView.numberOfPages)
		return;
	
	NSUInteger currentPage = self.paginatedView.currentPage;
	UIView *pageView = [self.paginatedView existingPageAtIndex:currentPage];
	[self adjustPageView:pageView usingGridAtIndex:currentPage];

}

- (void) viewDidLoad {

	[super viewDidLoad];
	
	self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"WAPatternLinedWood"]];
	self.view.opaque = YES;
	
	__weak IRPaginatedView *nrPaginatedView = self.paginatedView;
	self.paginatedView.backgroundColor = nil;
	self.paginatedView.horizontalSpacing = 32.0f;
	self.paginatedView.clipsToBounds = NO;
	self.paginatedView.scrollView.clipsToBounds = NO;
	self.paginatedView.onPointInsideWithEvent = ^ (CGPoint aPoint, UIEvent *anEvent, BOOL superAnswer) {
	
		CGPoint convertedPoint = [nrPaginatedView.scrollView convertPoint:aPoint fromView:nrPaginatedView];
		if ([nrPaginatedView.scrollView pointInside:convertedPoint withEvent:anEvent])
			return YES;
		
		return superAnswer;
	
	};
	
	if (self.discreteLayoutResult)
		[self.paginatedView reloadViews];
	
	self.paginationSlider.dotMargin = 32;
	self.paginationSlider.edgeInsets = (UIEdgeInsets){ 0, 16, 0, 16 };
	self.paginationSlider.backgroundColor = nil;
	self.paginationSlider.instantaneousCallbacks = YES;
	self.paginationSlider.layoutStrategy = WAPaginationSliderLessDotsLayoutStrategy;
	[self.paginationSlider irBind:@"currentPage" toObject:self.paginatedView keyPath:@"currentPage" options:nil];
	
	self.paginationSliderSlot.backgroundColor = [UIColor colorWithRed:0.75 green:0.55 blue:0.55 alpha:0.125];
	self.paginationSliderSlot.innerShadow = [IRShadow shadowWithColor:[UIColor colorWithWhite:0 alpha:0.625] offset:(CGSize){ 0, 2 } spread:6];
	self.paginationSliderSlot.layer.cornerRadius = 4.0f;
	self.paginationSliderSlot.layer.masksToBounds = YES;
	
}

- (void) setContextControlsVisible:(BOOL)contextControlsVisible animated:(BOOL)animated {

	NSLog(@"TBD %s", __PRETTY_FUNCTION__);

}

- (IRDiscreteLayoutManager *) discreteLayoutManager {

	if (discreteLayoutManager)
		return discreteLayoutManager;
		
	self.discreteLayoutManager = [IRDiscreteLayoutManager new];
	self.discreteLayoutManager.delegate = self;
	self.discreteLayoutManager.dataSource = self;
	return self.discreteLayoutManager;

}

- (NSArray *) layoutGrids {

	if (layoutGrids)
		return layoutGrids;
		
	layoutGrids = [self newLayoutGrids];
	return layoutGrids;

}

- (void) viewDidUnload {

	[self.paginationSlider irUnbind:@"currentPage"];
	[self.paginatedView irRemoveObserverBlocksForKeyPath:@"currentPage"];

	self.discreteLayoutManager = nil;
	self.discreteLayoutResult = nil;	//	TBD: Not really?
	
	[self setPaginationSliderSlot:nil];
	[super viewDidUnload];

}

-	(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
  
	return YES;
	
}

- (void) refreshData {

	//	Explicitly do nothing as otherwise it interferes with global entity syncing

}

- (void) viewWillAppear:(BOOL)animated {

	[super viewWillAppear:animated];
	
	if (self.paginatedView.numberOfPages)
		[self adjustPageView:[self.paginatedView existingPageAtIndex:self.paginatedView.currentPage] usingGridAtIndex:self.paginatedView.currentPage];
	
}

- (void) viewDidAppear:(BOOL)animated {

	[super viewDidAppear:animated];
	
	[[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(performReadingProgressSync) object:nil];
	[self performSelector:@selector(performReadingProgressSync) withObject:nil afterDelay:1];
	
}

- (void) controllerWillChangeContent:(NSFetchedResultsController *)controller {

	if ([self irHasDifferentSuperInstanceMethodForSelector:_cmd])
		[super controllerWillChangeContent:controller];

}

- (void) controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {
	
	if ([self irHasDifferentSuperInstanceMethodForSelector:_cmd])
		[super controller:controller didChangeObject:anObject atIndexPath:indexPath forChangeType:type newIndexPath:newIndexPath];
	
	switch (type) {
		
		case NSFetchedResultsChangeDelete:
		case NSFetchedResultsChangeInsert:
		case NSFetchedResultsChangeMove: {
			self.requiresRecalculationOnFetchedResultsChangeEnd = YES;
			break;
		}
		
		case NSFetchedResultsChangeUpdate: {
				
			if (!self.requiresRecalculationOnFetchedResultsChangeEnd)
			if ([anObject isKindOfClass:[WAArticle class]])
			if ([[[(WAArticle *)anObject changedValues] allKeys] containsObject:@"favorite"])
				self.requiresRecalculationOnFetchedResultsChangeEnd = YES;
			
			break;
			
		}
				
	}
		
}

- (void) controller:(NSFetchedResultsController *)controller didChangeSection:(id<NSFetchedResultsSectionInfo>)sectionInfo atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type {

	if ([self irHasDifferentSuperInstanceMethodForSelector:_cmd])
		[super controller:controller didChangeSection:sectionInfo atIndex:sectionIndex forChangeType:type];
	
	self.requiresRecalculationOnFetchedResultsChangeEnd = YES;

}

- (void) controllerDidChangeContent:(NSFetchedResultsController *)controller {

	if (self.requiresRecalculationOnFetchedResultsChangeEnd) {
			
		if ([self irHasDifferentSuperInstanceMethodForSelector:_cmd])
			[super controllerDidChangeContent:controller];
	
	}

}

- (void) reloadViewContents {

	NSError *layoutError = nil;
	IRDiscreteLayoutResult *result = [self.discreteLayoutManager calculatedResultWithReference:self.discreteLayoutResult strategy:IRCompareScoreLayoutStrategy error:&layoutError];
	
	if (!result) {
	
		[[[UIAlertView alloc] initWithTitle:@"Layout Manager Choked" message:[layoutError localizedDescription] delegate:nil cancelButtonTitle:NSLocalizedString(@"ACTION_OKAY", nil) otherButtonTitles:nil] show];
		
	}
	
	self.discreteLayoutResult = result;
	
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

- (NSInteger) layoutManager:(IRDiscreteLayoutManager *)manager indexOfLayoutItem:(id<IRDiscreteLayoutItem>)item {

	return [self.fetchedResultsController.fetchedObjects indexOfObject:item];

}

- (NSUInteger) numberOfLayoutGridsForLayoutManager:(IRDiscreteLayoutManager *)manager {

  return [self.layoutGrids count];

}

- (id<IRDiscreteLayoutItem>) layoutManager:(IRDiscreteLayoutManager *)manager layoutGridAtIndex:(NSUInteger)index {

  return (id<IRDiscreteLayoutItem>)[self.layoutGrids objectAtIndex:index];

}

- (NSInteger) layoutManager:(IRDiscreteLayoutManager *)manager indexOfLayoutGrid:(IRDiscreteLayoutGrid *)grid {

	return [self.layoutGrids indexOfObject:grid];

}

- (NSUInteger) numberOfViewsInPaginatedView:(IRPaginatedView *)paginatedView {

	return [self.discreteLayoutResult.grids count];

}

- (UIView *) viewForPaginatedView:(IRPaginatedView *)aPaginatedView atIndex:(NSUInteger)index {

	UIView *returnedView = [self newPageContainerView];
	returnedView.bounds = aPaginatedView.bounds;
	
	IRDiscreteLayoutGrid *viewGrid = (IRDiscreteLayoutGrid *)[self.discreteLayoutResult.grids objectAtIndex:index];
	
	NSMutableArray *pageElements = [NSMutableArray arrayWithCapacity:[viewGrid.layoutAreaNames count]];
	
	CGSize oldContentSize = viewGrid.contentSize;
	viewGrid.contentSize = aPaginatedView.frame.size;
	
	[viewGrid enumerateLayoutAreasWithBlock: ^ (NSString *name, id item, IRDiscreteLayoutGridAreaValidatorBlock validatorBlock, IRDiscreteLayoutGridAreaLayoutBlock layoutBlock, IRDiscreteLayoutGridAreaDisplayBlock displayBlock) {
	
		if (!item)
			return;
	
		UIView *placedSubview = (UIView *)displayBlock(viewGrid, item);
		NSParameterAssert(placedSubview);
		placedSubview.frame = layoutBlock(viewGrid, item);
		placedSubview.autoresizingMask = UIViewAutoresizingNone;
		[pageElements addObject:placedSubview];
		[returnedView addSubview:placedSubview];
				
	}];

	viewGrid.contentSize = oldContentSize;
	
	objc_setAssociatedObject(returnedView, &kWADiscreteArticlePageElements, pageElements, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	
	[returnedView setNeedsLayout];
	
	[self adjustPageView:returnedView usingGridAtIndex:index];
	
	return returnedView;

}

- (void) paginatedView:(IRPaginatedView *)paginatedView didShowView:(UIView *)aView atIndex:(NSUInteger)index {

	if ([self.discreteLayoutResult.grids count] <= index)
		return;
	
	IRDiscreteLayoutGrid *viewGrid = (IRDiscreteLayoutGrid *)[self.discreteLayoutResult.grids objectAtIndex:index];
	[viewGrid enumerateLayoutAreasWithBlock: ^ (NSString *name, id item, BOOL(^validatorBlock)(IRDiscreteLayoutGrid *self, id anItem), CGRect(^layoutBlock)(IRDiscreteLayoutGrid *self, id anItem), id(^displayBlock)(IRDiscreteLayoutGrid *self, id anItem)) {
	
		WAArticle *representedArticle = (WAArticle *)item;
			[((WAArticle *)item).representedFile thumbnailImage];
				
		for (WAPreview *aPreview in representedArticle.previews)
			[aPreview.graphElement thumbnail];
	
	}];

}

- (UIViewController *) viewControllerForSubviewAtIndex:(NSUInteger)index inPaginatedView:(IRPaginatedView *)paginatedView {

	return nil;

}

- (void) adjustPageViewAtIndex:(NSUInteger)anIndex {

	if (anIndex == NSNotFound)
		return;
	
	UIView *currentPageView = [self.paginatedView existingPageAtIndex:anIndex];
	
	if (currentPageView)
		[self adjustPageView:currentPageView usingGridAtIndex:anIndex];

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
	
	CGFloat currentAspectRatio = ((^ {
	
		//	FIXME: Save this
		
		UIWindow *usedWindow = self.view.window;
		if (!usedWindow)
			usedWindow = [UIApplication sharedApplication].keyWindow;
		
		NSParameterAssert(usedWindow);

		CGRect currentTransformedApplicationFrame = CGRectApplyAffineTransform(
			[usedWindow.screen applicationFrame],
			((CGAffineTransform[]){
				[UIInterfaceOrientationPortrait] = CGAffineTransformMakeRotation(0),
				[UIInterfaceOrientationPortraitUpsideDown] = CGAffineTransformMakeRotation(M_PI),
				[UIInterfaceOrientationLandscapeLeft] = CGAffineTransformMakeRotation(-0.5 * M_PI),
				[UIInterfaceOrientationLandscapeRight] = CGAffineTransformMakeRotation(0.5 * M_PI)
			})[self.interfaceOrientation]
		);
		
		CGFloat ratio = CGRectGetWidth(currentTransformedApplicationFrame) / CGRectGetHeight(currentTransformedApplicationFrame);
		NSCParameterAssert(isnormal(ratio));
		
		return ratio;

	})());
	
	for (IRDiscreteLayoutGrid *aGrid in allIntrospectedGrids) {
		
		if (!bestGrid) {
			bestGrid = aGrid;
			continue;
		}
		
		CGFloat bestGridAspectRatio = bestGrid.contentSize.width / bestGrid.contentSize.height;
		CGFloat currentGridAspectRatio = aGrid.contentSize.width / aGrid.contentSize.height;
		
		if (fabs(currentAspectRatio - bestGridAspectRatio) < fabs(currentAspectRatio - currentGridAspectRatio)) {
			continue;
		}
		
		bestGrid = aGrid;
		
	}
	
	
	IRDiscreteLayoutGrid *transformedGrid = bestGrid;//[allDestinations anyObject];
	transformedGrid = [currentPageGrid transformedGridWithPrototype:(transformedGrid.prototype ? transformedGrid.prototype : transformedGrid)];
	
	CGSize oldContentSize = transformedGrid.contentSize;
	transformedGrid.contentSize = self.paginatedView.frame.size;
			
	[transformedGrid enumerateLayoutAreasWithBlock: ^ (NSString *name, id item, BOOL(^validatorBlock)(IRDiscreteLayoutGrid *self, id anItem), CGRect(^layoutBlock)(IRDiscreteLayoutGrid *self, id anItem), id(^displayBlock)(IRDiscreteLayoutGrid *self, id anItem)) {
	
		if (!item)
			return;
			
		NSUInteger objectIndex = [currentPageGrid.layoutAreaNames indexOfObject:name];
		if (objectIndex != NSNotFound)
		if ([currentPageElements count] > objectIndex)
			((UIView *)[currentPageElements objectAtIndex:objectIndex]).frame = CGRectInset(layoutBlock(transformedGrid, item), 8, 8);
		
	}];
	
	transformedGrid.contentSize = oldContentSize;

}

- (void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {

	[super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
	
	NSUInteger const currentPage = self.paginatedView.currentPage;
	
	if (currentPage > 0)
		[self adjustPageViewAtIndex:(currentPage - 1)];
	
	[self adjustPageViewAtIndex:currentPage];
	[self adjustPageViewAtIndex:(currentPage + 1)];
	
	[self.paginatedView irRemoveAnimationsRecusively:YES];
	
}

- (NSUInteger) gridIndexOfArticle:(WAArticle *)anArticle {

	__block NSUInteger containingGridIndex = NSNotFound;

	IRDiscreteLayoutResult *lastLayoutResult = self.discreteLayoutResult;
	[lastLayoutResult.grids enumerateObjectsUsingBlock:^(IRDiscreteLayoutGrid *aGridInstance, NSUInteger gridIndex, BOOL *stop) {
	
		__block BOOL canStop = NO;
		
		[aGridInstance enumerateLayoutAreasWithBlock:^(NSString *name, id item, IRDiscreteLayoutGridAreaValidatorBlock validatorBlock, IRDiscreteLayoutGridAreaLayoutBlock layoutBlock, IRDiscreteLayoutGridAreaDisplayBlock displayBlock) {
			
			if ([item isEqual:anArticle]) {
				containingGridIndex = gridIndex;
				*stop = YES;
				canStop = YES;
			}
			
		}];
		
		*stop = canStop;
		
	}];
	
	return containingGridIndex;

}

- (void) paginationSlider:(WAPaginationSlider *)slider didMoveToPage:(NSUInteger)destinationPage {

	NSParameterAssert(destinationPage >= 0);
	NSParameterAssert(destinationPage < self.paginatedView.numberOfPages);

	if (self.paginatedView.currentPage == destinationPage)
		return;
	
	if ([slider.slider isTracking]) {
		UIViewAnimationOptions options = UIViewAnimationOptionAllowUserInteraction|UIViewAnimationOptionBeginFromCurrentState;
		[UIView animateWithDuration:0.3 delay:0 options:options animations:^{
			[self.paginatedView scrollToPageAtIndex:destinationPage animated:NO];			
		} completion:nil];
		return;
	}
	
	[self.paginatedView scrollToPageAtIndex:destinationPage animated:YES];
	
}

- (UIView *) viewForAnnotation:(WAPaginationSliderAnnotation *)anAnnotation inPaginationSlider:(WAPaginationSlider *)aSlider {

	if (anAnnotation == self.lastReadingProgressAnnotation)
		return self.lastReadingProgressAnnotationView;
	
	return nil;

}

- (BOOL) gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {

	return ![self.paginationSlider hitTest:[touch locationInView:self.paginationSlider] withEvent:nil];

}

- (BOOL) gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {

	return YES;

}

- (NSArray *) debugActionSheetControllerActions {

	NSMutableArray *returnedActions = [[super debugActionSheetControllerActions] mutableCopy];
	
	if (!WAAdvancedFeaturesEnabled())
		return returnedActions;
		
	__weak WADiscretePaginatedArticlesViewController *nrSelf = self;

	[returnedActions addObject:[IRAction actionWithTitle:@"Reflow" block: ^ {
		
		[nrSelf reloadViewContents];
		
	}]];
	
	return returnedActions;
	
}

- (void) dealloc {

	[self.paginationSlider irUnbind:@"currentPage"];
	[self.paginatedView irRemoveObserverBlocksForKeyPath:@"currentPage"];
		
	[[NSNotificationCenter defaultCenter] removeObserver:self];

}

@end
