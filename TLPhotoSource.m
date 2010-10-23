//
//  TLPhotoSource.m
//  Tagalog
//
//  Created by Nathan Vander Wilt on 1/26/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "TLPhotoSource.h"

NSString* const TLImageCaptureSourceDidUpdateNotification = @"TLImageCapture_SourceDidUpdate";

@interface TLPhotoSource ()
- (void)engage;
- (void)disengage;
@property (nonatomic, assign) NSUInteger leashCount;
@end


@implementation TLPhotoSource

@synthesize leashCount;

- (BOOL)isEngaged {
	return [self leashCount] ? YES : NO;
}

- (id)leash {
	// retain ourselves to encourage proper usage
	[self retain];
	NSUInteger oldCount = [self leashCount];
	[self setLeashCount:(oldCount+1)];
	if (!oldCount) {
		[self engage];
	}
	return self;
}

- (void)unleash {
	NSUInteger oldCount = [self leashCount];
	NSAssert(oldCount, @"Photo source was over-unleashed.");
	[self setLeashCount:(oldCount-1)];
	if (oldCount == 1) {
		[self disengage];
	}
	[self release];
}

- (void)engage {
	//NSLog(@"engaging source %p", self);
}
- (void)disengage {
	//NSLog(@"disengaged source %p", self);
}

- (NSString*)name {
	return nil;
}

- (NSImage*)icon {
	return nil;
}

- (NSSet*)items {
	return [NSSet set];
}

- (NSError*)error {
	return nil;
}

- (BOOL)isWorking {
	return NO;
}

- (BOOL)isCurrent {
	return YES;
}

@end
