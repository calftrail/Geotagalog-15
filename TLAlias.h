//
//  TLAlias.h
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 7/9/08.
//  Copyright 2008 Calf Trail Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/* Simple wrapper around Alias Manager functions. See also BDAlias and NDAlias. */

@interface TLAlias : NSObject {
@private
	void* internal;
}

+ (id)aliasWithPath:(NSString*)fullPath;

- (id)initWithPath:(NSString*)path relativeToPath:(NSString*)relativePath;
- (id)initWithPath:(NSString*)fullPath;
- (id)initWithData:(NSData*)data;

- (NSData*)aliasData;
- (NSString*)path;
- (NSString*)pathRelativeToPath:(NSString*)relativePath;

@end
