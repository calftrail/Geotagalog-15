//
//  TLPhotoSourceItem.m
//  Tagalog
//
//  Created by Nathan Vander Wilt on 6/1/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "TLPhotoSourceItem.h"

NSString* const TLMetadataTimestampKey = @"timestamp";
NSString* const TLMetadataTimezoneKey = @"timezone";
NSString* const TLMetadataLocationKey = @"location";


@implementation TLPhotoSourceItem

@synthesize source;

- (id)initWithSource:(TLPhotoSource*)theSource {
	self = [super init];
	if (self) {
		source = theSource;
	}
	return self;
}

- (NSString*)originalFilename {
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

- (NSDictionary*)metadata {
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

- (BOOL)canGeotag {
	[self doesNotRecognizeSelector:_cmd];
	return NO;
}

- (BOOL)canModifyOriginal {
	[self doesNotRecognizeSelector:_cmd];
	return NO;
}

- (CGImageRef)newThumbnailForSize:(CGFloat)approximateSize
						  options:(NSDictionary*)options
							error:(NSError**)err
{
	(void)approximateSize;
	(void)options;
	(void)err;
	[self doesNotRecognizeSelector:_cmd];
	return NULL;
}

- (BOOL)exportToPath:(NSURL*)path
			metadata:(NSDictionary*)metadata
			 options:(NSDictionary*)options
			   error:(NSError**)err;
{
	(void)path;
	(void)metadata;
	(void)options;
	(void)err;
	[self doesNotRecognizeSelector:_cmd];
	return NO;
}

- (BOOL)updateOriginalWithMetadata:(NSDictionary*)metadata
						   options:(NSDictionary*)options
							 error:(NSError**)err
{
	(void)metadata;
	(void)options;
	(void)err;
	[self doesNotRecognizeSelector:_cmd];
	return NO;
}

@end
