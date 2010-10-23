//
//  NSFileManager+TLExtensions.m
//  Tagalog
//
//  Created by Nathan Vander Wilt on 5/15/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "NSFileManager+TLExtensions.h"

static NSString* const TLNSFileManagerExtensionsThreadManagerKey = @"TLNSFileManagerExtensions_ThreadManager";


@implementation NSFileManager (TLNSFileManagerExtensions)

+ (NSFileManager*)tlThreadManager {
	NSFileManager* threadFileManager = nil;
	if ([NSThread isMainThread]) {
		threadFileManager = [NSFileManager defaultManager];
	}
	else {
		NSMutableDictionary* threadStorage = [[NSThread currentThread] threadDictionary];
		threadFileManager = [threadStorage objectForKey:TLNSFileManagerExtensionsThreadManagerKey];
		if (!threadFileManager) {
			threadFileManager = [[NSFileManager new] autorelease];
			[threadStorage setObject:threadFileManager forKey:TLNSFileManagerExtensionsThreadManagerKey];
		}
	}
	return threadFileManager;
}

- (NSString*)tlMoveItemAtPath:(NSString*)srcPath
				 toUniquePath:(NSString*)dstPath
						error:(NSError **)err
{
	BOOL moved = NO;
	NSUInteger uniqueFileSuffix = 0;
	const NSUInteger uniqueFileSuffixLimit = 1000000;
	NSString* finalDstPath = dstPath;
	do {
		if (uniqueFileSuffix) {
			NSString* fullFileName = [dstPath lastPathComponent];
			NSString* fileName = [fullFileName stringByDeletingPathExtension];
			NSString* dstFileName = [NSString stringWithFormat:@"%@-%lu", fileName, uniqueFileSuffix];
			
			NSString* dstFolder = [dstPath stringByDeletingLastPathComponent];
			NSString* dstExtension = [fullFileName pathExtension];
			finalDstPath = [[dstFolder stringByAppendingPathComponent:dstFileName]
							stringByAppendingPathExtension:dstExtension];
		}
		moved = [self moveItemAtPath:srcPath
							  toPath:finalDstPath
							   error:err];
		/* NOTE: we want to break if the error wasn't due to file already existing.
		 Unfortunately, the specific error when the file exists is undocumented, and was
		 seen to just be NSCocoaErrorDomain/NSFileWriteUnknownError, so that's not useful.
		 Instead we just break if the file doesn't exist *now*. This is not strictly correct,
		 but should work alright enough in practice. */
		if (!moved && ![self fileExistsAtPath:finalDstPath]) {
			break;
		}
	} while (!moved && ++uniqueFileSuffix < uniqueFileSuffixLimit);
	return moved ? finalDstPath : nil;
}


@end
