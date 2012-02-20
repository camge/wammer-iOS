//
//  WACompositionViewController.h
//  wammer-iOS
//
//  Created by Evadne Wu on 7/20/11.
//  Copyright 2011 Waveface. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
#import <AssetsLibrary/AssetsLibrary.h>

#import "AQGridView.h"
#import "IRTransparentToolbar.h"


@class IRImagePickerController, IRAction, WAArticle, WAPreviewBadge;

@interface WACompositionViewController : UIViewController

+ (WACompositionViewController *) controllerWithArticle:(NSURL *)anArticleURLOrNil completion:(void(^)(NSURL *anArticleURLOrNil))aBlock;

@property (nonatomic, readwrite, retain) IBOutlet UIView *containerView;
- (void) adjustContainerViewWithInterfaceBounds:(CGRect)newBounds;

@property (nonatomic, readwrite, retain) IBOutlet AQGridView *photosView;
@property (nonatomic, readwrite, retain) IBOutlet UITextView *contentTextView;
@property (nonatomic, readwrite, retain) IBOutlet IRTransparentToolbar *toolbar;
@property (nonatomic, readwrite, retain) IBOutlet UIView *noPhotoReminderView;

@property (nonatomic, readwrite, retain) IBOutletCollection(id) NSArray *noPhotoReminderViewElements;

- (IBAction) handleCameraItemTap:(UIButton *)sender;

@property (nonatomic, readwrite, assign) BOOL usesTransparentBackground;

@property (nonatomic, readonly, retain) WAPreviewBadge *previewBadge;
@property (nonatomic, readonly, retain) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, readonly, retain) WAArticle *article;

@end


@interface WACompositionViewController (SubclassResponsibility)

- (IBAction) handlePreviewBadgeTap:(id)sender;

@end


#import "WACompositionViewController+CustomUI.h"
#import "WACompositionViewController+ImageHandling.h"
