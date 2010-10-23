//
//  iPhotoExportController.m
//  Tagalog
//
//  Created by Nathan Vander Wilt on 5/15/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "iPhotoExportController.h"

#import "NSFileManager+TLExtensions.h"
#include <uuid/uuid.h>


@interface iPhotoExportController ()
@property (nonatomic, copy) NSString* autoImportFolder;
@end

static NSString* TLFileUniqueTemporaryPath(void);
static BOOL TLFileEnsureFolderExists(NSString* folder, NSError** err);
extern NSString* TLMakeUUID(void);


@implementation iPhotoExportController

@synthesize autoImportFolder;

- (void)dealloc {
	[self setAutoImportFolder:nil];
	[super dealloc];
}

- (BOOL)prepareForExport:(NSError**)err {
	CFStringRef autoImportPath = CFPreferencesCopyValue(CFSTR("iPhotoAutoImportPath"), CFSTR("com.apple.iApps"),
														kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
	if (!autoImportPath) {
		if (err) {
			NSDictionary* errInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									 @"Could not find current iPhoto libary's auto-import folder. "
									 @"If you have never used iPhoto, please use it to set up a library, then try again.",
									 NSLocalizedDescriptionKey, nil];
			*err = [NSError errorWithDomain:@"com.calftrail.tagalog" code:42 userInfo:errInfo];
		}
		return NO;
	}
	NSString* theAutoImportFolder = [(NSString*)autoImportPath stringByExpandingTildeInPath];
	CFRelease(autoImportPath);
	[self setAutoImportFolder:theAutoImportFolder];
	
	NSString* theTempFolder = TLFileUniqueTemporaryPath();
	BOOL folderExists = TLFileEnsureFolderExists(theTempFolder, NULL);
	if (!folderExists) {
		if (err) {
			NSDictionary* errInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									 @"Required temporary folder could not be created. "
									 @"If this continues please contact support@calftrail.com.",
									 NSLocalizedDescriptionKey, nil];
			*err = [NSError errorWithDomain:@"com.calftrail.tagalog" code:42 userInfo:errInfo];
		}
		return NO;
	}
	[self setFolder:theTempFolder];
	
	return [super prepareForExport:err];
}

- (void)cancelExport {
	// we don't remove our tempFolder because super will empty it anyway
	[super cancelExport];
}

- (BOOL)finishExport:(NSError**)err {
	/* NOTE: it would be atomically great if we could just copy the temporary export folder
	 directly into the auto import, but can't do this due to rdar://problem/6574259 */
	
	for (NSString* exportedPath in [self exportedPaths]) {
		NSString* filename = [exportedPath lastPathComponent];
		NSString* autoImportPath = [[self autoImportFolder] stringByAppendingPathComponent:filename];
		NSError* moveError;
		NSString* movedPath = [[NSFileManager tlThreadManager] tlMoveItemAtPath:exportedPath
																   toUniquePath:autoImportPath
																		  error:&moveError];
		if (!movedPath) {
			[self noteWarning:moveError];
		}
	}
	
	// remove folder (and any remaining contents), because it is our tempFolder
	[[NSFileManager tlThreadManager] removeItemAtPath:[self folder] error:NULL];
	
	NSTask* autoImport = [NSTask launchedTaskWithLaunchPath:@"/usr/bin/osascript" arguments:
						  [NSArray arrayWithObjects:@"-e",
						   @"tell application \"iPhoto\"\n"
						   @"  activate\n"
						   @"  auto import\n"
						   @"end tell", nil]];
	[autoImport waitUntilExit];
	
	return [super finishExport:err];
}

@end


BOOL TLFileEnsureFolderExists(NSString* folder, NSError** err) {
	NSString* fullPath = folder;
	BOOL mayCreate = YES;
	BOOL hideExtension = NO;
	
	BOOL success = YES;
	NSError* internalError;
	BOOL isDirectory = NO;
	NSFileManager* fileManager = [[NSFileManager new] autorelease];
	BOOL pathExists = [fileManager fileExistsAtPath:fullPath isDirectory:&isDirectory];
	if (pathExists && !isDirectory) {
		// make sure there's no file where we want our bundle directory
		NSDictionary* errorInfo = [NSDictionary dictionaryWithObject:fullPath forKey:NSFilePathErrorKey];
		internalError = [NSError errorWithDomain:NSPOSIXErrorDomain code:ENOTDIR userInfo:errorInfo];
		success = NO;
	}
	else if (!mayCreate && !pathExists) {
		// report if doesn't exist when it should
		NSDictionary* errorInfo = [NSDictionary dictionaryWithObject:fullPath forKey:NSFilePathErrorKey];
		internalError = [NSError errorWithDomain:NSPOSIXErrorDomain code:ENOENT userInfo:errorInfo];
		success = NO;
	}
	else if (!pathExists) {
		// create the directory
		NSDictionary* packageAttributes = nil;
		if (hideExtension) {
			packageAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
								 [NSNumber numberWithBool:YES], NSFileExtensionHidden, nil];
		}
		
		/* When tested on Leopard 10.5.4, the following call correctly resulted in an error
		 if intermediate path is blocked by file. */
		success = [fileManager createDirectoryAtPath:fullPath
						 withIntermediateDirectories:YES
										  attributes:packageAttributes
											   error:&internalError];
	}
	else {
		// all is well: pathExists and isDirectory
	}
	
	if (!success) {
		if (err) *err = internalError;
		return NO;
	}
	return YES;
}

NSString* TLFileUniqueTemporaryPath() {
	NSString* appIdentifier = [[NSBundle mainBundle] bundleIdentifier];
	NSString* uniqueFolder = [NSString stringWithFormat:@"%@-%@", appIdentifier, TLMakeUUID()];
	return [NSTemporaryDirectory() stringByAppendingPathComponent:uniqueFolder];
}

NSString* TLMakeUUID(void) {
	uuid_t uniqueIdentifier;
	uuid_generate(uniqueIdentifier);
	char stringBuffer[36+1];
	uuid_unparse(uniqueIdentifier, stringBuffer);
	return [NSString stringWithUTF8String:stringBuffer];
}
