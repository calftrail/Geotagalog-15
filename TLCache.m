//
//  TLCache.m
//  Mercatalog
//
//  Created by Jon Hjelle on 11/22/08.
//  Copyright 2008 Calf Trail Software, LLC. All rights reserved.
//

#import "TLCache.h"


@implementation TLCache

#pragma mark Lifecycle

- (id)init {
    self = [super init];
	if (self) {
		keys = [NSMutableArray new];
		objects = [[NSMapTable mapTableWithStrongToStrongObjects] retain];
	}
	return self;
}

- (void)dealloc {
	[keys release];
    [objects release];
	[super dealloc];
}


#pragma mark Accessors

#ifdef TLCACHE_COUNT
- (void)noteUseOfKey:(id)key {
	[keys removeObject:key];
	[keys addObject:key];
}

- (void)removeItem {
	id victim = [keys objectAtIndex:0];
	[objects removeObjectForKey:victim];
	[keys removeObject:victim];
}

@synthesize countLimit;

- (void)setCountLimit:(NSUInteger)newCountLimit {
	countLimit = newCountLimit;
	while (countLimit && [keys count] > countLimit) {
		[self removeItem];
	}
}
#endif /* TLCACHE_COUNT */

- (id)objectForKey:(id)key {
#ifdef TLCACHE_COUNT
	[self noteUseOfKey:key];
#endif
	return [objects objectForKey:key];
}

- (void)setObject:(id)object forKey:(id)key {
#ifdef TLCACHE_COUNT
	[self noteUseOfKey:key];
	
	id existingObject = [objects objectForKey:key];
	if (!existingObject &&
		[self countLimit] &&
		[objects count] == [self countLimit])
	{
		[self removeItem];
	}
#endif /* TLCACHE_COUNT */
	[objects setObject:object forKey:key];
}

@end
