//
//  WAArticleTextEmphasisLabel.h
//  wammer-iOS
//
//  Created by Evadne Wu on 8/16/11.
//  Copyright 2011 Waveface. All rights reserved.
//

#import <CoreText/CoreText.h>
#import <UIKit/UIKit.h>

#import "IRLabel.h"

@interface WAArticleTextEmphasisLabel : UIView

@property (nonatomic, readwrite, copy) NSString *text;
@property (nonatomic, readwrite, copy) NSString *placeholder;	//	Defaults to nil; if exists, draws at 50% gray
@property (nonatomic, readwrite, retain) UIFont *font;
@property (nonatomic, readwrite, retain) IBOutlet UIView *backgroundView;

@property (nonatomic, readonly, retain) IBOutlet IRLabel *label;

@end
