//
//  TLUnprojectionTable.m
//  Mercatalog
//
//  Created by Jon Hjelle on 11/19/08.
//  Copyright 2008 Calf Trail Software, LLC. All rights reserved.
//

#import "TLUnprojectionTable.h"


@implementation TLUnprojectionTable

#pragma mark Lifecycle

- (id)initWithBounds:(TLBounds)theBounds
      sampleDistance:(CGSize)proposedSampleDistance
          projection:(TLProjectionRef)theProj
{
    self = [super init];
    if (self) {
        proj = TLProjectionCopy(theProj);
        if (!proj) {
            [self dealloc];
            return nil;
        }
        
        tl_uint_t numDivisionsX = lround(theBounds.size.width / proposedSampleDistance.width);
        tl_uint_t numDivisionsY = lround(theBounds.size.height / proposedSampleDistance.height);
        table = malloc((numDivisionsY + 1) * (numDivisionsX + 1) * sizeof(TLCoordinate));
        if (!table) {
            [self dealloc];
            return nil;
        }
        
        CGFloat divisionWidth = theBounds.size.width / numDivisionsX;
        CGFloat divisionHeight = theBounds.size.height / numDivisionsY;
        
        tableWidth = numDivisionsX + 1;
        tableLength = (numDivisionsX + 1) * (numDivisionsY + 1);
        origin = theBounds.origin;
        divisionSize = CGSizeMake(divisionWidth, divisionHeight);
        
        TLCoordinate* currentCoordinatePtr = table;
        TLCoordinate nanCoord = TLCoordinateMake(NAN, NAN);
        for (tl_uint_t yIdx = 0; yIdx <= numDivisionsY; ++yIdx) {
            CGFloat mapPointY = theBounds.origin.y + (yIdx * divisionHeight);
            for (tl_uint_t xIdx = 0; xIdx <= numDivisionsX; ++xIdx) {
                CGPoint mapPoint = CGPointMake(theBounds.origin.x + (xIdx * divisionWidth), mapPointY);
                
                TLProjectionError err = TLProjectionErrorNone;
                TLCoordinate coord = TLProjectionUnprojectPoint(theProj, mapPoint, &err);
                if (!err) {
                    *currentCoordinatePtr = coord;
                }
                else {
                    *currentCoordinatePtr = nanCoord;
                }
                
                ++currentCoordinatePtr;
            }
        }
    }
    return self;
}

- (void)dealloc {
    TLProjectionRelease(proj);
    if (table) free(table);
    [super dealloc];
}

+ (id)unprojectionTableWithBounds:(TLBounds)bounds
                   sampleDistance:(CGSize)sampleDistance
                       projection:(TLProjectionRef)proj
{
    TLUnprojectionTable* table = [[[self class] alloc] initWithBounds:bounds
                                                       sampleDistance:sampleDistance
                                                           projection:proj];
    return [table autorelease];
}

- (TLCoordinate)coordinateForPoint:(CGPoint)mapPoint error:(TLProjectionError*)err {
    CGFloat tableX = (mapPoint.x - origin.x) / divisionSize.width;
    CGFloat tableY = (mapPoint.y - origin.y) / divisionSize.height;
    // when not on a sample point, values in each dimension will be 1 apart
    tl_uint_t leftX = (tl_uint_t)floor(tableX);
    tl_uint_t rightX = (tl_uint_t)ceil(tableX);
    tl_uint_t lowerY = (tl_uint_t)floor(tableY);
    tl_uint_t upperY = (tl_uint_t)ceil(tableY);
    
    tl_uint_t topLeftIdx = TLTableIndex(leftX, upperY, tableWidth);
    tl_uint_t topRightIdx = TLTableIndex(rightX, upperY, tableWidth);
    tl_uint_t bottomRightIdx = TLTableIndex(rightX, lowerY, tableWidth);
    tl_uint_t bottomLeftIdx = TLTableIndex(leftX, lowerY, tableWidth);
    NSAssert(topLeftIdx < tableLength &&
             topRightIdx < tableLength &&
             bottomRightIdx < tableLength &&
             bottomLeftIdx < tableLength,
             @"Map point out of bounds");
    
    TLCoordinate topLeftCoord = table[topLeftIdx];
    TLCoordinate topRightCoord = table[topRightIdx];
    TLCoordinate bottomRightCoord = table[bottomRightIdx];
    TLCoordinate bottomLeftCoord = table[bottomLeftIdx];
    
    CGFloat pointDiffX = tableX - leftX;
    CGFloat pointDiffY = tableY - lowerY;
    CGFloat travelX = pointDiffX;   // assume (rightX - leftX) denominator is 1
    CGFloat travelY = pointDiffY;   // assume (upperY - lowerY) denominator is 1
    
    TLCoordinateDegrees dLatTop = topRightCoord.lat - topLeftCoord.lat;
    TLCoordinateDegrees dLonTop = topRightCoord.lon - topLeftCoord.lon;
	if (fabs(dLonTop) > TLProjectionInfoHemisphere) {
		dLonTop = NAN;
	}
    TLCoordinate topCoord = TLCoordinateMake(topLeftCoord.lat + (travelX * dLatTop),
                                             topLeftCoord.lon + (travelX * dLonTop));
    
    TLCoordinateDegrees dLatBottom = bottomRightCoord.lat - bottomLeftCoord.lat;
    TLCoordinateDegrees dLonBottom = bottomRightCoord.lon - bottomLeftCoord.lon;
	if (fabs(dLonBottom) > TLProjectionInfoHemisphere) {
		dLonBottom = NAN;
	}
    TLCoordinate bottomCoord = TLCoordinateMake(bottomLeftCoord.lat + (travelX * dLatBottom),
                                                bottomLeftCoord.lon + (travelX * dLonBottom));
    
    TLCoordinateDegrees dLat = topCoord.lat - bottomCoord.lat;
    TLCoordinateDegrees dLon = topCoord.lon - bottomCoord.lon;
	if (fabs(dLon) > TLProjectionInfoHemisphere) {
		dLon = NAN;
	}
    TLCoordinate coordinate = TLCoordinateMake(bottomCoord.lat + (travelY * dLat),
                                               bottomCoord.lon + (travelY * dLon));
    
    if (isnan(coordinate.lat) || isnan(coordinate.lon)) {
        TLProjectionError internalError = TLProjectionErrorNone;
        TLCoordinate exactCoordinate = TLProjectionUnprojectPoint(proj, mapPoint, &internalError);
        if (internalError) {
            if (err) *err = internalError;
        }
        else {
            coordinate = exactCoordinate;
        }
    }
    
    return coordinate;
}


@end
