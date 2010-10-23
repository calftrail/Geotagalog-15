//
//  TLPhotoSourceItem.h
//  Tagalog
//
//  Created by Nathan Vander Wilt on 6/1/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TLPhotoSource;

@interface TLPhotoSourceItem : NSObject {
@private
	TLPhotoSource* source;
}

- (id)initWithSource:(TLPhotoSource*)theSource;

@property (nonatomic, readonly) TLPhotoSource* source;
@property (nonatomic, readonly) NSString* originalFilename;
@property (nonatomic, readonly) NSDictionary* metadata;
@property (nonatomic, readonly) BOOL canGeotag;
@property (nonatomic, readonly) BOOL canModifyOriginal;

- (CGImageRef)newThumbnailForSize:(CGFloat)approximateSize
						  options:(NSDictionary*)options
							error:(NSError**)err;

- (BOOL)exportToPath:(NSURL*)path
			metadata:(NSDictionary*)metadata
			 options:(NSDictionary*)options
			   error:(NSError**)err;

- (BOOL)updateOriginalWithMetadata:(NSDictionary*)metadata
						   options:(NSDictionary*)options
							 error:(NSError**)err;

@end

extern NSString* const TLMetadataTimestampKey;
extern NSString* const TLMetadataTimezoneKey;
extern NSString* const TLMetadataLocationKey;
