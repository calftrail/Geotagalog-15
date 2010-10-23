//
//  NSFileManager+TLExtensions.h
//  Tagalog
//
//  Created by Nathan Vander Wilt on 5/15/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSFileManager (TLNSFileManagerExtensions)

+ (NSFileManager*)tlThreadManager;

- (NSString*)tlMoveItemAtPath:(NSString*)srcPath
				 toUniquePath:(NSString*)dstPath
						error:(NSError **)error;

// TODO: add ensureFolderExists, etc.

@end
