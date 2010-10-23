//
//  TLProjectBundle.h
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 7/9/08.
//  Copyright 2008 Calf Trail Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/* Like a bundle, but removes localization and enables at least showing path-critical parts
 TLProjectBundle is somewhat analagous to a very simple NSBundle. But whereas NSBundle is
 designed for application data, with support for localizations, multiple architectures, and
 frameworks, this is designed for facilitating access to a set of packaged user data files.
 
 As the user may choose to move this package at any time, some effort is made to reduce the
 potentially harmful effects of such an action. However, no guarantees are made.
 */

enum {
	TLProjectBundleFlagMustExist = 1 << 0
};
typedef NSUInteger TLProjectBundleFlags;


@class TLAlias;

@interface TLProjectBundle : NSObject {
@private
	BOOL closed;
	NSUndoManager* undoManager;
	TLAlias* locationAlias;
	NSMutableDictionary* tokens;
}

- (id)initWithURL:(NSURL*)projectURL options:(TLProjectBundleFlags)flags error:(NSError**)err;

// designated initializers for subclasses
- (BOOL)createWithOptions:(TLProjectBundleFlags)flags error:(NSError**)err;
- (BOOL)loadWithOptions:(TLProjectBundleFlags)flags error:(NSError**)err;

- (void)close;

@property (nonatomic, retain) NSUndoManager* undoManager;

- (NSString*)currentBundlePath;
- (void)ensureDirectoryExists:(NSString*)projectSubdirectory;

@end


typedef NSInteger TLProjectBundleLockToken;

@interface TLProjectBundle (TLProjectBundlePathHelpers)

- (TLProjectBundleLockToken)createTokenForFile:(NSString*)filename inDirectory:(NSString*)projectSubdirectory;
- (TLProjectBundleLockToken)createTokenForFile:(NSString*)projectPath;
- (TLProjectBundleLockToken)createTokenForDirectory:(NSString*)projectSubdirectory;
- (void)releaseToken:(TLProjectBundleLockToken)token;

- (NSString*)fullPathForToken:(TLProjectBundleLockToken)token;

@end
