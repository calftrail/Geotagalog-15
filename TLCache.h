//
//  TLCache.h
//  Mercatalog
//
//  Created by Jon Hjelle on 11/22/08.
//  Copyright 2008 Calf Trail Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


//#define TLCACHE_COUNT

@interface TLCache : NSObject {
@private
#ifdef TLCACHE_COUNT
	NSUInteger countLimit;
#endif
	NSMutableArray* keys;
    NSMapTable* objects;
}

#ifdef TLCACHE_COUNT
@property (nonatomic, assign) NSUInteger countLimit;
#endif

- (id)objectForKey:(id)key;
- (void)setObject:(id)object forKey:(id)key;

@end
