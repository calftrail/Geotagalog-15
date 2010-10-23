//
//  FolderExportController.m
//  Tagalog
//
//  Created by Nathan Vander Wilt on 5/13/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "FolderExportController.h"

#import "TLMainThreadPerformer.h"
#import "NSFileManager+TLExtensions.h"
#import "TLPhotoSourceItem.h"

extern NSString* TLMakeUUID(void);


@implementation FolderExportController

@synthesize folder;
@synthesize exportedPaths = mutableExportedPaths;

- (id)init {
	self = [super init];
	if (self) {
		mutableExportedPaths = [NSMutableArray new];
	}
	return self;
}

- (void)dealloc {
	[self setFolder:nil];
	[mutableExportedPaths release];
	[super dealloc];
}


#pragma mark Export implementation

- (BOOL)prepareForExport:(NSError**)err {
	BOOL isDirectory = NO;
	BOOL exists = [[NSFileManager tlThreadManager] fileExistsAtPath:[self folder]
														isDirectory:&isDirectory];
	if (!exists) {
		if (err) {
			NSDictionary* errInfo = [NSDictionary dictionaryWithObject:[self folder]
																forKey:NSFilePathErrorKey];
			*err = [NSError errorWithDomain:NSPOSIXErrorDomain
									   code:ENOENT
								   userInfo:errInfo];
		}
		return NO;
	}
	if (!isDirectory) {
		if (err) {
			NSDictionary* errInfo = [NSDictionary dictionaryWithObject:[self folder]
																forKey:NSFilePathErrorKey];
			*err = [NSError errorWithDomain:NSPOSIXErrorDomain
									   code:ENOTDIR
								   userInfo:errInfo];
		}
		return NO;
	}
	return YES;
}

- (NSDictionary*)photoExportOptions {
	return nil;
	/* TODO: old code
	[NSDictionary dictionaryWithObject:[NSTimeZone systemTimeZone]
									   forKey:TLPhotoTimezoneExportOption];
	 */
}

- (BOOL)exportItem:(TLPhotoSourceItem*)item
	  withMetadata:(NSDictionary*)metadata
			 error:(NSError**)err
{
	// export file to unique hidden path
	NSString* photoName = [[item originalFilename] stringByDeletingPathExtension];
	NSString* photoExtension = [[item originalFilename] pathExtension];
	NSString* hiddenPhotoName = [NSString stringWithFormat:
								 @".temp.%@.%@.%@", photoName, TLMakeUUID(), photoExtension];
	NSString* tempPath = [[self folder] stringByAppendingPathComponent:hiddenPhotoName];
	BOOL exported = [item exportToPath:[NSURL fileURLWithPath:tempPath isDirectory:NO]
							  metadata:metadata
							   options:nil
								 error:err];
	if (!exported) return NO;
	
	// move hidden export to a unique visible file
	NSString* exportPath = [[self folder] stringByAppendingPathComponent:[item originalFilename]];
	NSString* finalExportPath = [[NSFileManager tlThreadManager] tlMoveItemAtPath:tempPath
																	 toUniquePath:exportPath
																			error:err];
	if (!finalExportPath) return NO;
	
	[mutableExportedPaths addObject:finalExportPath];
	return YES;
}

- (BOOL)copyItem:(TLPhotoSourceItem*)item
		   error:(NSError**)err
{
	(void)item;
	(void)err;
	return [self exportItem:item withMetadata:nil error:err];
}

- (void)cancelExport {
	for (NSString* exportedPath in [self exportedPaths]) {
		(void)[[NSFileManager tlThreadManager] removeItemAtPath:exportedPath error:NULL];
	}
	[mutableExportedPaths removeAllObjects];
}

@end
