//
//  TLAlias.m
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 7/9/08.
//  Copyright 2008 Calf Trail Software, LLC. All rights reserved.
//

#import "TLAlias.h"

// see http://developer.apple.com/documentation/Carbon/Reference/Alias_Manager/Reference/reference.html
#include <CoreServices/CoreServices.h>

static Handle TLCreateHandleFromData(CFDataRef data) {
	// see also http://lists.apple.com/archives/carbon-dev/2005/Jan/msg00749.html
	// see also http://developer.apple.com/qa/qa2004/qa1350.html
	CFIndex dataLength = CFDataGetLength(data);
	Handle handle = NewHandle(dataLength);
	if (handle) {
		HLock(handle);	// see http://developer.apple.com/DOCUMENTATION/mac/Memory/Memory-88.html
		memcpy(*handle, CFDataGetBytePtr(data), dataLength);
		HUnlock(handle);
	}
	return handle;
}

static CFDataRef TLCreateDataFromHandle(Handle handle) {
	Size handleSize = GetHandleSize(handle);
	HLock(handle);
	CFDataRef data = CFDataCreate(kCFAllocatorDefault, (UInt8*)*handle, handleSize);
	HUnlock(handle);
	return data;
}

@interface TLAlias (TLAliasPrivateMethods)
- (AliasHandle)newAliasHandleFromPath:(NSString*)path relativeToPath:(NSString*)relativePath;

@end

@implementation TLAlias

#pragma mark Internal accessors

- (AliasHandle)aliasHandle {
	return (AliasHandle)internal;
}

- (void)setAliasHandle:(AliasHandle)newAlias {
	// do nothing if setting same handle
	if (internal == newAlias) return;
	
	// free the old handle
	Handle oldAlias = (Handle)[self aliasHandle];
	if (oldAlias) {
		DisposeHandle(oldAlias);
	}
	
	// set the new handle
	internal = newAlias;
}

#pragma mark Lifecycle

- (id)initWithAlias:(AliasHandle)alias {
	self = [super init];
	if (self) {
		[self setAliasHandle:alias];
	}
	return self;	
}

- (void)dealloc {
	[self setAliasHandle:NULL];
	[super dealloc];
}

- (id)initWithPath:(NSString*)path relativeToPath:(NSString*)relativePath {
	AliasHandle alias = [self newAliasHandleFromPath:path relativeToPath:relativePath];
	return [self initWithAlias:alias];
}

- (id)initWithPath:(NSString*)fullPath {
	return [self initWithPath:fullPath relativeToPath:nil];
}

+ (id)aliasWithPath:(NSString*)fullPath {
	TLAlias* alias = [[TLAlias alloc] initWithPath:fullPath];
	return [alias autorelease];
}

#pragma mark Data conversion

- (AliasHandle)newAliasHandleFromPath:(NSString*)path relativeToPath:(NSString*)relativePath {
	AliasHandle alias = NULL;
	OSErr result = FSNewAliasFromPath([relativePath UTF8String], [path UTF8String], 0, &alias, NULL);
	(void)result;
	return alias;
}

- (id)initWithData:(NSData*)data {
	AliasHandle alias = (AliasHandle)TLCreateHandleFromData((CFDataRef)data);
	return [self initWithAlias:alias];
}

- (NSData*)aliasData {
	NSData* data = (NSData*)TLCreateDataFromHandle((Handle)[self aliasHandle]);
	return [data autorelease];
}

# pragma mark Public path accessors

- (NSString*)pathRelativeToPath:(NSString*)relativePath {
	// Convert relativePath to FSRef unless nil.
	FSRef relativeRef;
	const FSRef* relativeRefPtr = &relativeRef;
	if (relativePath) {
		OSStatus relPathResult = FSPathMakeRef((const UInt8*)[relativePath UTF8String], &relativeRef, NULL);
		if (relPathResult) return nil;
	}
	else relativeRefPtr = NULL;
	
	// Resolve alias if possible
	Boolean wasChanged = false;
	FSRef aliasTarget;
	OSErr result = FSResolveAlias(relativeRefPtr, [self aliasHandle], &aliasTarget, &wasChanged);
	(void)wasChanged;
	if (result) return nil;
	
	// Convert resolved FSRef back to string
	CFURLRef pathAsURL = CFURLCreateFromFSRef(kCFAllocatorDefault, &aliasTarget);
	NSString* path = [(NSURL*)pathAsURL path];
	CFRelease(pathAsURL);
	return path;
}

- (NSString*)path {
	return [self pathRelativeToPath:nil];
}

@end
