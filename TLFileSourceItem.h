//
//  TLFileSourceItem.h
//  Tagalog
//
//  Created by Nathan Vander Wilt on 6/5/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "TLPhotoSourceItem.h"

@class TLFilePhotoSource;

@interface TLFileSourceItem : TLPhotoSourceItem {
@private
	NSString* filePath;
	NSString* fileUTI;
	NSDictionary* metadata;
	CGImageSourceRef imageSource;
}

- (id)initWithSource:(TLFilePhotoSource*)source
			filePath:(NSString*)theFilePath
			   error:(NSError**)err;

@property (nonatomic, readonly, copy) NSString* filePath;

@end
