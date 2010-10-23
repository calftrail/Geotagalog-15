//
//  TLPhotoSource.h
//  Tagalog
//
//  Created by Nathan Vander Wilt on 1/26/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface TLPhotoSource : NSObject {
@private
	NSUInteger leashCount;
}

- (id)leash;
- (void)unleash;

@property (nonatomic, readonly) NSString* name;
@property (nonatomic, readonly) NSImage* icon;

@property (nonatomic, readonly) BOOL isCurrent;
@property (nonatomic, readonly) NSSet* items;
@property (nonatomic, readonly) NSError* error;
// this can be observed to show background activity
@property (nonatomic, readonly) BOOL isWorking;
@end

@interface TLPhotoSource (TLPhotoSourceSubclasses)
@property (nonatomic, readonly) BOOL isEngaged;
- (void)engage;
- (void)disengage;
@end

extern NSString* const TLImageCaptureSourceDidUpdateNotification;
