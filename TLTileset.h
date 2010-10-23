//
//  TLTileset.h
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 11/24/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "TLCoordinate.h"

@class TLCache;

@interface TLTileset : NSObject {
@private
	TLCache* tileCache;
}

- (TLCoordinateDegrees)minimumDegreesPerPixel;

- (size_t)bytesPerPixel;
- (void*)pixelForCoordinate:(TLCoordinate)coord degreesPerPixel:(TLCoordinateDegrees)scale;

@end

@interface TLMemoryBackedContext : NSObject {
@private
	CGContextRef ctx;
}
+ (id)memoryBackedContextWithWidth:(size_t)width height:(size_t)height;
- (id)initWithContext:(CGContextRef)theQuartzContext;
@property (nonatomic, readonly) CGContextRef quartzContext;
@end

size_t TLCGBitmapContextGetBytesPerPixel(CGContextRef context);

