//
//  TLMapFrameLayer.m
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 8/5/08.
//  Copyright 2008 Calf Trail Software, LLC. All rights reserved.
//

#import "TLMapFrameLayer.h"

#import "TLCocoaToolbag.h"
#import "TLProjectionInfo.h"
#import "TLProjectionGeometry.h"
#import "TLProjectedDrawing.h"

@implementation TLMapFrameLayer

- (void)drawInContext:(CGContextRef)ctx withInfo:(id < TLMapInfo >)mapInfo {
	// draw paper-white background
	CGRect drawableBox = CGContextGetClipBoundingBox(ctx);
	CGContextAddRect(ctx, drawableBox);
	CGColorRef backgroundColor = TLCGColorCreateGenericHSB(0.15f, 0.02f, 0.97f, 1.0f);
	CGContextSetFillColorWithColor(ctx, backgroundColor);
	CGColorRelease(backgroundColor);
	CGContextFillPath(ctx);
	
	// draw range frame
	CGFloat significantDistance = TLSizeGetAverageWidth([mapInfo significantVisualSize]);
	TLMultiPolygonRef projectionRange = TLProjectionInfoCreateRange([mapInfo projection], significantDistance);
	if (projectionRange) {
		CGPathRef rangePath = TLCGPathCreateFromMultiPolygon(projectionRange, YES, significantDistance);
		TLMultiPolygonRelease(projectionRange);
		CGContextAddPath(ctx, rangePath);
		CGPathRelease(rangePath);
		CGColorRef frameColor = TLCGColorCreateGenericHSB(0.0f, 1.0f, 0.0f, 0.7f);
		CGContextSetStrokeColorWithColor(ctx, frameColor);
		CGColorRelease(frameColor);
		CGFloat mmSize = TLSizeGetAverageWidth([mapInfo millimeterSize]);
		CGContextSetLineWidth(ctx, 0.5f * mmSize);
		CGContextStrokePath(ctx);
	}
}

@end
