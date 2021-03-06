//
//  WARemoteInterfaceContext.h
//  wammer
//
//  Created by Evadne Wu on 11/4/11.
//  Copyright (c) 2011 Waveface. All rights reserved.
//

#import "IRWebAPIEngineContext.h"


extern NSString * const kWARemoteInterfaceContextDidChangeBaseURLNotification;
extern NSString * const kWARemoteInterfaceContextOldBaseURL;	//	NSURL in user info
extern NSString * const kWARemoteInterfaceContextNewBaseURL;	//	NSURL in user info

@interface WARemoteInterfaceContext : IRWebAPIEngineMutableContext

+ (WARemoteInterfaceContext *) context;

@end
