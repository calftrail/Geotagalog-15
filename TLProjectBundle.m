//
//  TLProjectBundle.m
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 7/9/08.
//  Copyright 2008 Calf Trail Software, LLC. All rights reserved.
//

#import "TLProjectBundle.h"

#import "TLAlias.h"
#include <sys/errno.h>

@interface TLProjectBundle ()
- (BOOL)ensureExistenceOfDirectory:(NSString*)fullPath
						 mayCreate:(BOOL*)didCreate
					 hideExtension:(BOOL)hideExtension
							 error:(NSError**)err;
@end

@implementation TLProjectBundle

#pragma mark Lifecycle

+ (TLProjectBundle*)projectMatchingPath:(NSString*)fullPath {
	(void)fullPath;
	// NOTE: Singleton semantics not currently enforced
	return nil;
}

- (id)initWithURL:(NSURL*)projectURL options:(TLProjectBundleFlags)flags error:(NSError**)err {
	// Check for project with same path
	NSString* fullPath = [projectURL path];
	TLProjectBundle* existingProject = [TLProjectBundle projectMatchingPath:fullPath];
	if (existingProject) {
		// see http://lists.apple.com/archives/ObjC-Language/2008/Sep/msg00133.html for [super dealloc] rationale
		[super dealloc];
		return [existingProject retain];
	}
	
	// Otherwise, do "normal" initialization
	self = [super init];
	if (self) {
		// handle directory creation
		BOOL createAllowed = !(flags & TLProjectBundleFlagMustExist);
		BOOL didCreate = NO;
		BOOL directoryExists = [self ensureExistenceOfDirectory:fullPath
													  mayCreate:(createAllowed ? &didCreate : NULL)
												  hideExtension:YES
														  error:err];
		if (!directoryExists) {
			[super dealloc];
			return nil;
		}
		
		// initialize ivars
		locationAlias = [[TLAlias alloc] initWithPath:fullPath];
		tokens = [NSMutableDictionary new];
		
		// try loading subclass
		BOOL success = NO;
		if (didCreate) {
			success = [self createWithOptions:flags error:err];
		}
		else {
			success = [self loadWithOptions:flags error:err];
		}
		
		if (!success) {
			[locationAlias release];
			[tokens release];
			[super dealloc];
			self = nil;
		}
	}
	return self;
}

- (void)close {
	NSAssert(![tokens count], @"Cannot close with outstanding path tokens");
	closed = YES;
}

- (void)dealloc {
	NSAssert(closed, @"Dealloc sent to open project bundle");
	[undoManager release];
	[locationAlias release];
	[tokens release];
	[super dealloc];
}


#pragma mark Stub subclass intializers

- (BOOL)createWithOptions:(TLProjectBundleFlags)flags error:(NSError**)err {
	(void)flags;
	(void)err;
	return YES;
}

- (BOOL)loadWithOptions:(TLProjectBundleFlags)flags error:(NSError**)err {
	(void)flags;
	(void)err;
	return YES;
}


#pragma mark Accessors

- (void)setUndoManager:(NSUndoManager*)newUndoManager {
	[undoManager autorelease];
	undoManager = [newUndoManager retain];
}

- (NSUndoManager*)undoManager {
	if (!undoManager) {
		undoManager = [[NSUndoManager alloc] init];
	}
	return undoManager;
}

#pragma mark Internal path methods

- (NSString*)currentBundlePath {
	return [locationAlias path];
}

- (void)ensureDirectoryExists:(NSString*)projectSubdirectory {
	NSString* fullPath = [[self currentBundlePath] stringByAppendingPathComponent:projectSubdirectory];
	BOOL didCreate = YES;
	(void)[self ensureExistenceOfDirectory:fullPath mayCreate:&didCreate hideExtension:NO error:NULL];
}

- (BOOL)ensureExistenceOfDirectory:(NSString*)fullPath
						 mayCreate:(BOOL*)didCreate
					 hideExtension:(BOOL)hideExtension
							 error:(NSError**)err
{
	BOOL noCreate = !(didCreate);
	NSError* internalError = nil;
	BOOL createdDir = NO;
	
	BOOL isDirectory = NO;
	BOOL pathExists = [[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDirectory];
	if (pathExists && !isDirectory) {
		// make sure there's no file where we want our bundle directory
		NSDictionary* errorInfo = [NSDictionary dictionaryWithObject:fullPath forKey:NSFilePathErrorKey];
		internalError = [NSError errorWithDomain:NSPOSIXErrorDomain code:ENOTDIR userInfo:errorInfo];
	}
	else if (noCreate && !pathExists) {
		// report if doesn't exist when it should
		NSDictionary* errorInfo = [NSDictionary dictionaryWithObject:fullPath forKey:NSFilePathErrorKey];
		internalError = [NSError errorWithDomain:NSPOSIXErrorDomain code:ENOENT userInfo:errorInfo];
	}
	else if (!pathExists) {
		// create the directory
		NSDictionary* packageAttributes = nil;
		if (hideExtension) {
			packageAttributes = [NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithBool:YES], NSFileExtensionHidden, nil];
		}
		
		// When tested on Leopard 10.5.4, the following call correctly resulted in an error if intermediate path is blocked by file.
		NSError* createDirError;
		createdDir = [[NSFileManager defaultManager] createDirectoryAtPath:fullPath
											   withIntermediateDirectories:YES
																attributes:packageAttributes
																	 error:&createDirError];
		if (!createdDir) {
			internalError = createDirError;
		}
	}
	else {
		// all is well: pathExists and isDirectory
	}
	
	if (didCreate) *didCreate = createdDir;
	if (internalError && err) *err = internalError;
	return internalError ? NO : YES;
}

@end


@implementation TLProjectBundle (TLProjectBundlePathHelpers)

#pragma mark Path locking

/* NOTE: Right now these provide no protection, but in the future a safe location on the project's filesystem should be
 used to store a temporary copy of the file until released. 
 See http://www.cocoadev.com/index.pl?GettingTemporaryFolderOnSpecificVolume but also consider using a hidden sibling. */

- (id)keyForToken:(TLProjectBundleLockToken)token {
	return [NSNumber numberWithInteger:token];
}

- (TLProjectBundleLockToken)uniqueToken {
	TLProjectBundleLockToken token = NSIntegerMax;
	while (token > 0) {
		id key = [self keyForToken:token];
		NSString* path = [tokens objectForKey:key];
		if (!path) break;
		--token;
	}
	return token;
}

- (TLProjectBundleLockToken)createTokenForFile:(NSString*)filename inDirectory:(NSString*)projectSubdirectory {
	if (!projectSubdirectory) projectSubdirectory = @"";
	NSString* fullDirectory = [[self currentBundlePath] stringByAppendingPathComponent:projectSubdirectory];
	BOOL didCreate = YES;
	[self ensureExistenceOfDirectory:fullDirectory mayCreate:&didCreate hideExtension:NO error:NULL];
	
	TLProjectBundleLockToken token = [self uniqueToken];
	NSAssert(token, @"Invalid project file token");
	
	if (!filename) filename = @"";
	NSString* projectPath = [projectSubdirectory stringByAppendingPathComponent:filename];
	id key = [self keyForToken:token];
	[tokens setObject:projectPath forKey:key];
	
	return token;
}

- (TLProjectBundleLockToken)createTokenForFile:(NSString*)projectPath {
	NSMutableArray* components = [[[projectPath pathComponents] mutableCopy] autorelease];
	NSString* filename = [components lastObject];
	[components removeLastObject];
	NSString* directory = [NSString pathWithComponents:components];
	return [self createTokenForFile:filename inDirectory:directory];
}

- (TLProjectBundleLockToken)createTokenForDirectory:(NSString*)projectSubdirectory {
	return [self createTokenForFile:nil inDirectory:projectSubdirectory];
}

- (void)releaseToken:(TLProjectBundleLockToken)token {
	id key = [self keyForToken:token];
	[tokens removeObjectForKey:key];
}

- (NSString*)fullPathForToken:(TLProjectBundleLockToken)token {
	id key = [self keyForToken:token];
	NSString* subpath = [tokens objectForKey:key];
	NSString* projectPath = [self currentBundlePath];
	return [projectPath stringByAppendingPathComponent:subpath];
}

@end
