//
//  WAArticlesViewController.m
//  wammer-iOS
//
//  Created by Evadne Wu on 8/31/11.
//  Copyright 2011 Waveface Inc. All rights reserved.
//

#import "WAArticlesViewController.h"
#import "WADataStore.h"
#import "WARemoteInterface.h"
#import "WARemoteInterface+ScheduledDataRetrieval.h"
#import "WADataStore+WARemoteInterfaceAdditions.h"
#import "WACompositionViewController.h"
#import "WACompositionViewController+CustomUI.h"

#import "IRBarButtonItem.h"
#import "IRTransparentToolbar.h"
#import "IRActionSheetController.h"
#import "IRActionSheet.h"
#import "IRAlertView.h"
#import "IRMailComposeViewController.h"

#import "WAOverlayBezel.h"
#import "UIApplication+CrashReporting.h"

#import "WAView.h"
#import "UIImage+IRAdditions.h"

#import "WARefreshActionView.h"

#import "WAArticleDraftsViewController.h"

#import "WAUserInfoViewController.h"

#import "WANavigationController.h"

#import "IASKAppSettingsViewController.h"

@interface WAArticlesViewController () <NSFetchedResultsControllerDelegate, WAArticleDraftsViewControllerDelegate>

@property (nonatomic, readwrite, retain) NSFetchedResultsController *fetchedResultsController;
@property (nonatomic, readwrite, retain) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, readwrite, retain) IRActionSheetController *debugActionSheetController;
@property (nonatomic, readwrite, retain) UIPopoverController *draftsPopoverController;
@property (nonatomic, readwrite, retain) UIPopoverController *userInfoPopoverController;

@property (nonatomic, readwrite, assign) BOOL updatesViewOnControllerChangeFinish;

@property (nonatomic, readwrite, assign) int interfaceUpdateOperationSuppressionCount;
@property (nonatomic, readwrite, retain) NSOperationQueue *interfaceUpdateOperationQueue;

- (void) beginCompositionSessionForArticle:(NSURL *)anObjectURI;

- (void) dismissAuxiliaryControlsAnimated:(BOOL)animate;

- (void) handleUserInfoItemTap:(id)sender;
- (void) handleComposeItemTap:(id)sender;

@end


@implementation WAArticlesViewController
@synthesize delegate, fetchedResultsController, managedObjectContext;
@synthesize debugActionSheetController;
@synthesize draftsPopoverController;
@synthesize userInfoPopoverController;
@synthesize updatesViewOnControllerChangeFinish;
@synthesize interfaceUpdateOperationSuppressionCount, interfaceUpdateOperationQueue;

- (id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {

	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	if (!self)
		return nil;
		
	NSFetchRequest *fr = [[[WADataStore defaultStore] newFetchRequestForAllArticles] autorelease];
	fr.fetchBatchSize = 100;
	fr.sortDescriptors = [NSArray arrayWithObjects:
		[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:YES],
	nil];
		
	self.managedObjectContext = [[WADataStore defaultStore] defaultAutoUpdatedMOC];
	self.fetchedResultsController = [[[NSFetchedResultsController alloc] initWithFetchRequest:fr managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:nil] autorelease];
	
	self.fetchedResultsController.delegate = self;
	
	[self.fetchedResultsController performFetch:nil];
	
	self.navigationItem.titleView = WAStandardTitleView();
		
	self.navigationItem.leftBarButtonItem = [IRBarButtonItem itemWithCustomView:((^ {
	
		UIView *wrapperView = [[[UIView alloc] initWithFrame:(CGRect){ 0, 0, 32, 24 }] autorelease];
		WARefreshActionView *actionView = [[[WARefreshActionView alloc] initWithRemoteInterface:[WARemoteInterface sharedInterface]] autorelease];
		
		[wrapperView addSubview:actionView];
		actionView.frame = IRCGRectAlignToRect(actionView.frame, wrapperView.bounds, irRight, YES);
		
		return wrapperView;
	
	})())];
	
	self.navigationItem.rightBarButtonItem = [IRBarButtonItem itemWithCustomView:((^ {
  
    __block __typeof__(self) nrSelf = self;
		
    IRTransparentToolbar *toolbar = [[[IRTransparentToolbar alloc] initWithFrame:(CGRect){ 0, 0, 180, 44 }] autorelease];
		
		toolbar.usesCustomLayout = NO;
		toolbar.items = [NSMutableArray arrayWithObjects:
		
			[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil] autorelease],
		
			((^ {
			
				__block IRBarButtonItem *senderItem = WABarButtonItem([UIImage imageNamed:@"WAUserGlyph"], nil, ^{

					[nrSelf handleUserInfoItemTap:senderItem];
				
				});
				
				return senderItem;
			
			})()),
			
			((^ {
			
				__block IRBarButtonItem *senderItem = WABarButtonItem([UIImage imageNamed:@"WACompose"], nil, ^{

					[nrSelf handleComposeItemTap:senderItem];
				
				});
				
				return senderItem;
			
			})()),
								
		nil];
		
		UIView *returnedView = [[[UIView alloc] initWithFrame:toolbar.bounds] autorelease];
		[returnedView addSubview:toolbar];
		toolbar.frame = CGRectOffset(toolbar.frame, 10, 0);
		
		return returnedView;
	
	})())];
	
	self.title = @"Articles";
	
	self.interfaceUpdateOperationQueue = [[[NSOperationQueue alloc] init] autorelease];
	
	return self;
	
}

- (void) dealloc {

	[fetchedResultsController release];
	[managedObjectContext release];
	[debugActionSheetController release];
	
	if ([userInfoPopoverController isPopoverVisible])
		[userInfoPopoverController dismissPopoverAnimated:NO];
  
	[userInfoPopoverController release];
	
  [draftsPopoverController release];
	
	[interfaceUpdateOperationQueue release];

	[super dealloc];

}





//	Implicitly trigger a remote data refresh after view load

- (void) viewDidLoad {

	[super viewDidLoad];

}

- (void) viewWillAppear:(BOOL)animated {

	[super viewWillAppear:animated];
	[self reloadViewContents];	
	[self refreshData];

}

- (void) viewWillDisappear:(BOOL)animated {

	[super viewWillDisappear:animated];
  [self dismissAuxiliaryControlsAnimated:NO];

}

- (void) viewDidUnload {

	self.debugActionSheetController = nil;
  self.draftsPopoverController = nil;
  self.userInfoPopoverController = nil;
	
	[super viewDidUnload];

}

- (void) refreshData {

	BOOL hasExistingData = !![self.fetchedResultsController.fetchedObjects count];
	
	if (hasExistingData)
		[[WARemoteInterface sharedInterface] rescheduleAutomaticRemoteUpdates];
	else
		[[WARemoteInterface sharedInterface] performAutomaticRemoteUpdatesNow];

}


- (void) controllerDidChangeContent:(NSFetchedResultsController *)controller {
	
	if ([self isViewLoaded]) {
	
		[[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(reloadViewContents) object:nil];
		[self performSelector:@selector(reloadViewContents) withObject:nil afterDelay:0.01];
		
	}
	
}

- (void) reloadViewContents {

	[NSException raise:NSInternalInconsistencyException format:@"%@ shall be implemented in a subclass only, and you should not call super.", NSStringFromSelector(_cmd)];

}

- (NSURL *) representedObjectURIForInterfaceItem:(UIView *)aView {

	[NSException raise:NSInternalInconsistencyException format:@"%@ shall be implemented in a subclass only, and you should not call super.", NSStringFromSelector(_cmd)];
	return nil;

}

- (UIView *) interfaceItemForRepresentedObjectURI:(NSURL *)anURI createIfNecessary:(BOOL)createsOffsecreenItemIfNecessary {

	[NSException raise:NSInternalInconsistencyException format:@"%@ shall be implemented in a subclass only, and you should not call super.", NSStringFromSelector(_cmd)];
	return nil;

}





- (void) dismissAuxiliaryControlsAnimated:(BOOL)animate {

  if ([userInfoPopoverController isPopoverVisible])
    [userInfoPopoverController dismissPopoverAnimated:animate];
  
  if ([draftsPopoverController isPopoverVisible])
    [draftsPopoverController dismissPopoverAnimated:animate];
    
  if ([debugActionSheetController.managedActionSheet isVisible])
    [debugActionSheetController.managedActionSheet dismissWithClickedButtonIndex:[debugActionSheetController.managedActionSheet cancelButtonIndex] animated:animate];

}

- (UIPopoverController *) userInfoPopoverController {

  if (userInfoPopoverController)
    return userInfoPopoverController;
    
  __block __typeof__(self) nrSelf = self;
  __block WAUserInfoViewController *userInfoVC = [[[WAUserInfoViewController alloc] init] autorelease];
  __block UINavigationController *wrappingNavC = [[[WANavigationController alloc] initWithRootViewController:userInfoVC] autorelease];
  
  userInfoVC.navigationItem.rightBarButtonItem = [IRBarButtonItem itemWithSystemItem:UIBarButtonSystemItemAction wiredAction:^(IRBarButtonItem *senderItem) {
    
    if ([nrSelf.debugActionSheetController.managedActionSheet isVisible])
      [nrSelf.debugActionSheetController.managedActionSheet dismissWithClickedButtonIndex:0 animated:NO];
    
    [nrSelf.debugActionSheetController.managedActionSheet showInView:userInfoVC.view];
    
  }];
    
  userInfoPopoverController = [[UIPopoverController alloc] initWithContentViewController:wrappingNavC];
  return userInfoPopoverController;

}

- (void) handleUserInfoItemTap:(UIBarButtonItem *)sender {

  [self dismissAuxiliaryControlsAnimated:NO];
  [self.userInfoPopoverController presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionUp animated:NO];

}





- (NSArray *) debugActionSheetControllerActions {
	
	__block __typeof__(self) nrSelf = self;

	NSMutableArray *returnedArray = [NSMutableArray arrayWithObjects:
	
		[IRAction actionWithTitle:NSLocalizedString(@"ACTION_SIGN_OUT", @"Action title for Signing Out") block: ^ {
		
			[[IRAlertView alertViewWithTitle:NSLocalizedString(@"ACTION_SIGN_OUT", @"Action title for Signing Out") message:NSLocalizedString(@"SIGN_OUT_CONFIRMATION", @"Confirmation text for Signing Out") cancelAction:[IRAction actionWithTitle:NSLocalizedString(@"ACTION_CANCEL", @"Action title for Cancelling") block:nil] otherActions:[NSArray arrayWithObjects:
			
				[IRAction actionWithTitle:NSLocalizedString(@"ACTION_SIGN_OUT", @"Action title for Signing Out") block: ^ {
				
					dispatch_async(dispatch_get_main_queue(), ^ {
					
						[nrSelf.delegate applicationRootViewControllerDidRequestReauthentication:nrSelf];
							
					});

				}],
			
			nil]] show];
		
		}],
  
  nil];
  
  if (WAAdvancedFeaturesEnabled()) {
  
    [returnedArray addObjectsFromArray:[NSArray arrayWithObjects:
      
      [IRAction actionWithTitle:NSLocalizedString(@"ACTION_FEEDBACK", @"Action title for feedback composition") block:^ {
      
        if (![IRMailComposeViewController canSendMail]) {
          [[[[IRAlertView alloc] initWithTitle:@"Email Disabled" message:@"Add a mail account to enable this." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease] show];
          return;
        }
        
        __block IRMailComposeViewController *composeViewController;
        composeViewController = [IRMailComposeViewController controllerWithMessageToRecipients:[NSArray arrayWithObjects:@"ev@waveface.com",	nil] withSubject:NSLocalizedString(@"NOUN_CURRENT_DEVICE", @"Title for Waveface Feedback") messageBody:nil inHTML:NO completion:^(MFMailComposeViewController *controller, MFMailComposeResult result, NSError *error) {
          [composeViewController dismissModalViewControllerAnimated:YES];
        }];
        
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
          composeViewController.modalPresentationStyle = UIModalPresentationFormSheet;
        
        [nrSelf presentModalViewController:composeViewController animated:YES];
      
      }],
      
      [IRAction actionWithTitle:@"Simulate Crash" block: ^ {
      
        ((char *)NULL)[1] = 0;
      
      }],
			
			[IRAction actionWithTitle:@"Simulate Crashlytics Crash" block: ^ {
      
        WF_CRASHLYTICS(^ {
				
					[[Crashlytics sharedInstance] crash];
				
				});
      
      }],
			
			[IRAction actionWithTitle:@"Trigger Token Expiry" block:^{
			
				[[NSNotificationCenter defaultCenter] postNotificationName:kWARemoteInterfaceDidObserveAuthenticationFailureNotification object:nil];
			
			}],
    
      [IRAction actionWithTitle:@"Import Test Photos" block: ^ {
      
        dispatch_async(dispatch_get_global_queue(0, 0), ^ {
      
          ALAssetsLibrary *library = [[[ALAssetsLibrary alloc] init] autorelease];
          
          NSString *sampleDirectory = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"IPSample"];
          
          [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:sampleDirectory error:nil] enumerateObjectsUsingBlock: ^ (NSString *aFileName, NSUInteger idx, BOOL *stop) {
            
            NSString *filePath = [sampleDirectory stringByAppendingPathComponent:aFileName];
            
            UIImage *image = [UIImage imageWithContentsOfFile:filePath];
            
            if (!image)
              return;
              
            [library writeImageToSavedPhotosAlbum:image.CGImage metadata:nil completionBlock:^(NSURL *assetURL, NSError *error) {
            
              NSLog(@"%s %@ %@", __PRETTY_FUNCTION__, assetURL, error);
              
            }];
                    
          }];
        
        });
      
      }],
      
      [IRAction actionWithTitle:@"Remove Resources" block:^ {
      
        NSManagedObjectContext *context = [[WADataStore defaultStore] disposableMOC];
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
        
        [[context executeFetchRequest:((^ {
          NSFetchRequest *fr = [[[NSFetchRequest alloc] init] autorelease];
          fr.entity = [NSEntityDescription entityForName:@"WAFile" inManagedObjectContext:context];
          fr.predicate = [NSPredicate predicateWithFormat:@"(resourceURL != nil) || (thumbnailURL != nil)"];
          return fr;
        })()) error:nil] enumerateObjectsUsingBlock: ^ (WAFile *aFile, NSUInteger idx, BOOL *stop) {
        
					NSString *resourcePath = [aFile primitiveValueForKey:@"resourceFilePath"];
					NSString *thumbnailPath = [aFile primitiveValueForKey:@"thumbnailFilePath"];
				
          if (resourcePath) {
            [[NSFileManager defaultManager] removeItemAtPath:resourcePath error:nil];
            aFile.resourceFilePath = nil;
          }
          
          if (thumbnailPath) {
            [[NSFileManager defaultManager] removeItemAtPath:thumbnailPath error:nil];
            aFile.thumbnailFilePath = nil;
          }
					
        }];
        
        NSError *savingError = nil;
        if (![context save:&savingError]) {
          NSLog(@"Error saving: %@", savingError);
					NSParameterAssert(NO);
				}
      
      }],
    
    nil]];
  
  }
  
  return returnedArray;
		
}

- (IRActionSheetController *) debugActionSheetController {

	if (debugActionSheetController)
		return debugActionSheetController;
		
	debugActionSheetController = [[IRActionSheetController actionSheetControllerWithTitle:nil cancelAction:[IRAction actionWithTitle:NSLocalizedString(@"ACTION_CANCEL", @"Cancel.") block:nil] destructiveAction:nil otherActions:[self debugActionSheetControllerActions]] retain];
	
	return debugActionSheetController;

}








- (UIPopoverController *) draftsPopoverController {

  if (draftsPopoverController)
    return draftsPopoverController;

  WAArticleDraftsViewController *draftsVC = [[[WAArticleDraftsViewController alloc] init] autorelease];
  draftsVC.delegate = self;
  UINavigationController *navC = [[[WANavigationController alloc] initWithRootViewController:draftsVC] autorelease];
  draftsPopoverController = [[UIPopoverController alloc] initWithContentViewController:navC];
  
  return draftsPopoverController;

}

- (void) handleComposeItemTap:(UIBarButtonItem *)sender {

  BOOL hasDrafts = [[WADataStore defaultStore] hasDraftArticles];
    
  if (hasDrafts) {
  
    if ([draftsPopoverController isPopoverVisible])
      return;
    
    [self dismissAuxiliaryControlsAnimated:NO];
    [self.draftsPopoverController presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionUp animated:NO];
    
    return;
    
  }
  
  [self dismissAuxiliaryControlsAnimated:NO];
  [self beginCompositionSessionForArticle:nil];
  
}

- (BOOL) articleDraftsViewController:(WAArticleDraftsViewController *)aController shouldEnableArticle:(NSURL *)anObjectURIOrNil {

	return ![[WADataStore defaultStore] isUploadingArticle:anObjectURIOrNil];

}

- (void) articleDraftsViewController:(WAArticleDraftsViewController *)aController didSelectArticle:(NSURL *)anObjectURIOrNil {

  [self dismissAuxiliaryControlsAnimated:NO];
  [self beginCompositionSessionForArticle:anObjectURIOrNil];

}

- (void) beginCompositionSessionForArticle:(NSURL *)anURI {

	__block WACompositionViewController *compositionVC = [WACompositionViewController defaultAutoSubmittingCompositionViewControllerForArticle:anURI completion:^(NSURL *anURI) {
		
		[compositionVC dismissModalViewControllerAnimated:YES];
		
	}];
	
	UINavigationController *wrapperNC = [compositionVC wrappingNavigationController];
	wrapperNC.modalPresentationStyle = UIModalPresentationFormSheet;
	
	[(self.navigationController ? self.navigationController : self) presentModalViewController:wrapperNC animated:YES];

}





NSString * const kLoadingBezel = @"loadingBezel";

- (void) remoteDataLoadingWillBegin {

	[self remoteDataLoadingWillBeginForOperation:nil];

}

- (void) remoteDataLoadingWillBeginForOperation:(NSString *)aMethodName {

	NSParameterAssert([NSThread isMainThread]);
		
	if ([aMethodName isEqualToString:@"refreshData"]) {
		//	Only show on first load, when there is nothing displayed yet
		if ([self.fetchedResultsController.fetchedObjects count])
			return;
	}

	WAOverlayBezel *bezel = [WAOverlayBezel bezelWithStyle:WADefaultBezelStyle];
	bezel.caption = @"Loading";
	
	[bezel show];
	
	objc_setAssociatedObject(self, &kLoadingBezel, bezel, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

}

- (void) remoteDataLoadingDidEnd {

	WAOverlayBezel *bezel = objc_getAssociatedObject(self, &kLoadingBezel);
	
	[[bezel retain] autorelease];
	objc_setAssociatedObject(self, &kLoadingBezel, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	
	[bezel dismissWithAnimation:WAOverlayBezelAnimationFade|WAOverlayBezelAnimationZoom];

}

- (void) remoteDataLoadingDidFailWithError:(NSError *)anError {

	WAOverlayBezel *bezel = objc_getAssociatedObject(self, &kLoadingBezel);
	[bezel dismissWithAnimation:WAOverlayBezelAnimationFade|WAOverlayBezelAnimationZoom];
	
	//	Showing an error bezel here is inappropriate.
	//	We might be doing an implicit thing, in that case we should NOT use a bezel at all
	
	//	WAOverlayBezel *errorBezel = [WAOverlayBezel bezelWithStyle:WAErrorBezelStyle];
	//	[errorBezel show];
	//	
	//	double delayInSeconds = 2.0;
	//	dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
	//	dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
	//    [errorBezel dismissWithAnimation:WAOverlayBezelAnimationZoom];
	//	});

}





- (void) performInterfaceUpdate:(void(^)(void))aBlock {

	[self.interfaceUpdateOperationQueue addOperation:[NSBlockOperation blockOperationWithBlock: ^ {
	
		dispatch_async(dispatch_get_main_queue(), ^ {
		
			if (aBlock)
				aBlock();
		
		});
		
	}]];

}

- (void) beginDelayingInterfaceUpdates {

	self.interfaceUpdateOperationSuppressionCount += 1;
	
	if (self.interfaceUpdateOperationSuppressionCount)
		[self.interfaceUpdateOperationQueue setSuspended:YES];

}

- (void) endDelayingInterfaceUpdates {

	self.interfaceUpdateOperationSuppressionCount -= 1;
	
	if (!self.interfaceUpdateOperationSuppressionCount)
		[self.interfaceUpdateOperationQueue setSuspended:NO];

}

- (BOOL) isDelayingInterfaceUpdates {

	return [self.interfaceUpdateOperationQueue isSuspended];

}





- (void) didReceiveMemoryWarning {

	[self retain];
	[super didReceiveMemoryWarning];
	[self release];

}

@end
