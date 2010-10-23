//
//  TLNaturalEarthLayer.m
//  Mercatalog
//
//  Created by Jon Hjelle on 9/17/08.
//  Copyright 2008 Calf Trail Software, LLC. All rights reserved.
//

#import "TLNaturalEarthLayer.h"

#include "TLProjectionInfo.h"
#include "TLGeometry.h"
#include "TLProjectedDrawing.h"

#import "TLUnprojectionTable.h"
#import "TLTileset.h"

//#define TIMESTART NSDate* startDate = [NSDate date];
//#define TIMEEND printf("Elapsed time %0.3fs\n", [[NSDate date] timeIntervalSinceDate:startDate]);
#define TIMESTART
#define TIMEEND





@implementation TLNaturalEarthLayer

#pragma mark Lifecycle

- (id)init {
	self = [super init];
	if (self) {
		tileset = [TLTileset new];
	}
	return self;
}

- (void)dealloc {
    [tileset release];
    [super dealloc];
}


#pragma mark Drawing

- (void)drawInContext:(CGContextRef)ctx withInfo:(id < TLMapInfo >)mapInfo {
	TIMESTART
	
	static const CGFloat deresolution = 1.0f;
	CGSize proposedDestinationPixelSize = CGSizeMake(deresolution * mapInfo.significantVisualSize.width,
													 deresolution * mapInfo.significantVisualSize.height);
	TLProjectionRef proj = [mapInfo projection];
    TLProjectionGeoidMeters radius = TLProjectionGeoidGetEquatorialRadius(TLProjectionGetPlanetModel(proj));
    CGFloat proposedPixelDistance = TLSizeGetAverageWidth(proposedDestinationPixelSize);
    TLCoordinateDegrees proposedDegreesPerPixel = (proposedPixelDistance / radius) * TLCoordinateRadiansToDegrees;
	TLCoordinateDegrees availableTileDegreesPerPixel = [tileset minimumDegreesPerPixel];
	TLCoordinateDegrees degreesPerPixel = fmax(proposedDegreesPerPixel, availableTileDegreesPerPixel);
	
	double unadjustedPixelDistance = (degreesPerPixel * TLCoordinateDegreesToRadians) * radius;
	TLBounds drawingBounds = CGContextGetClipBoundingBox(ctx);
	tl_uint_t destinationWidth = (tl_uint_t)lround(drawingBounds.size.width / unadjustedPixelDistance);
    tl_uint_t destinationHeight = (tl_uint_t)lround(drawingBounds.size.height / unadjustedPixelDistance);
	if (destinationWidth * destinationHeight > 825000) {
		destinationWidth = (destinationWidth * 85) / 100;
		destinationHeight = (destinationHeight * 85) / 100;
	}
	destinationWidth = MAX(2, destinationWidth);
	destinationHeight = MAX(2, destinationHeight);
	CGSize destinationPixelSize = CGSizeMake(drawingBounds.size.width / destinationWidth,
											 drawingBounds.size.height / destinationHeight);
	
	TLMemoryBackedContext* destinationContext = [TLMemoryBackedContext memoryBackedContextWithWidth:destinationWidth
																							 height:destinationHeight];
	CGContextRef destinationBitmap = [destinationContext quartzContext];
    if (!destinationBitmap) {
        return;
    }
    
    size_t destinationBytesPerPixel = TLCGBitmapContextGetBytesPerPixel(destinationBitmap);
    size_t sourceBytesPerPixel = [tileset bytesPerPixel];
    NSAssert(destinationBytesPerPixel == sourceBytesPerPixel,
			 @"Source and destination bitmap pixel sizes must be identical.");
    size_t bitmapBytesPerPixel = destinationBytesPerPixel;
	NSAssert(bitmapBytesPerPixel == 4, @"Code assumes 32-bit pixels");
	typedef int32_t tlnel_pixel_t;
    
    tl_uint_t samplingInterval = 10;
    CGSize sampleDistance = CGSizeMake(mapInfo.significantVisualSize.width * samplingInterval,
                                       mapInfo.significantVisualSize.height * samplingInterval);
    TLUnprojectionTable* unprojectionTable = [TLUnprojectionTable unprojectionTableWithBounds:drawingBounds
                                                                               sampleDistance:sampleDistance
                                                                                   projection:proj];
	
	tlnel_pixel_t* destPixel = CGBitmapContextGetData(destinationBitmap);
	NSAssert(destPixel, @"Output context must provide memory access");
	for (tl_uint_t destBitmapY = 0; destBitmapY < destinationHeight; ++destBitmapY) {
		tl_uint_t destinationRowFromBottom = destinationHeight - 1 - destBitmapY;
		CGFloat yOffset = destinationRowFromBottom * destinationPixelSize.height;
		CGFloat mapY = drawingBounds.origin.y + yOffset;
		for (tl_uint_t destBitmapX = 0; destBitmapX < destinationWidth; ++destBitmapX, ++destPixel) {
			CGFloat xOffset = destBitmapX * destinationPixelSize.width;
			CGFloat mapX = drawingBounds.origin.x + xOffset;
			
            CGPoint mapPoint = CGPointMake(mapX, mapY);
            TLProjectionError err = TLProjectionErrorNone;
            TLCoordinate coordinate = [unprojectionTable coordinateForPoint:mapPoint error:&err];
            if (err) continue;
			
			void* sourcePixelPtr = [tileset pixelForCoordinate:coordinate degreesPerPixel:degreesPerPixel];
			if (sourcePixelPtr) {
				*destPixel = *(tlnel_pixel_t*)sourcePixelPtr;
			}
        }
    }
	
	TLMultiPolygonRef projectionRange = NULL;
	if (TLProjectionNamesEqual(TLProjectionNameRobinson, TLProjectionGetName(proj))) {
		projectionRange = TLProjectionInfoCreateRange(proj, mapInfo.significantVisualSize.width);
	}
	if (projectionRange) {
		CGPathRef rangePath = TLCGPathCreateFromMultiPolygon(projectionRange, YES,
                                                             mapInfo.significantVisualSize.width);
		TLMultiPolygonRelease(projectionRange);
		CGContextAddPath(ctx, rangePath);
		CGPathRelease(rangePath);
        CGContextClip(ctx);
    }
	
    CGImageRef finalImage = CGBitmapContextCreateImage(destinationBitmap);
    if (finalImage) {
        CGContextDrawImage(ctx, drawingBounds, finalImage);
        CGImageRelease(finalImage);
    }
	TIMEEND;
}

@end

