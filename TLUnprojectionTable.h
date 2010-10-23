//
//  TLUnprojectionTable.h
//  Mercatalog
//
//  Created by Jon Hjelle on 11/19/08.
//  Copyright 2008 Calf Trail Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#include "TLBounds.h"
#include "TLProjection.h"

@interface TLUnprojectionTable : NSObject {
@private
    TLProjectionRef proj;
    TLCoordinate* table;
    tl_uint_t tableWidth;
    tl_uint_t tableLength;
    CGPoint origin;
    CGSize divisionSize;
}

+ (id)unprojectionTableWithBounds:(TLBounds)bounds
                   sampleDistance:(CGSize)sampleDistance
                       projection:(TLProjectionRef)proj;

- (TLCoordinate)coordinateForPoint:(CGPoint)mapPoint error:(TLProjectionError*)err;

@end
