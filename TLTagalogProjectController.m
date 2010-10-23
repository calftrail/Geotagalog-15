//
//  TLTagalogProjectController.m
//  Tagalog
//
//  Created by Nathan Vander Wilt on 1/23/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "TLTagalogProjectController.h"

#import "TLMapView.h"
#import "TLGraticuleMapLayer.h"
#import "TLNaturalEarthLayer.h"
#import "TLTrackLayer.h"
#import "TLPhotoLayer.h"
#import "TLMapBevel.h"

#import "TLTrack.h"
#import "TLWaypoint.h"
#import "TLLocation.h"
#include "TLGeometry.h"
#import "TLCocoaToolbag.h"

#import "TimeOffsetController.h"
#import "PhotoSourceController.h"
#import "MetadataController.h"
#import "iPhotoExportController.h"

#import "TLJimBos.h"


extern NSArray* TLNSArrayShuffle(NSArray* array);
static TLProjectionRef TLProjectionCreateStereographicWithCenter(TLCoordinateDegrees lat,
																 TLCoordinateDegrees lon);


@interface TLTagalogProjectController ()
- (void)fitMapViewToTracks;
@end


@implementation TLTagalogProjectController

@synthesize window;
@synthesize tracks;
@synthesize waypoints;
@synthesize sourceController;

- (void)addTracks:(NSSet*)newTracks {
	[tracks unionSet:newTracks];
	[self fitMapViewToTracks];
}

- (void)removeTracks:(NSSet*)oldTracks {
	// we never remove tracks, this just enables automatic KVO
	(void)oldTracks;
	[self doesNotRecognizeSelector:_cmd];
}

- (void)addWaypoints:(NSSet*)newWaypoints {
	[waypoints unionSet:newWaypoints];
}

- (void)removeWaypoints:(NSSet*)oldWaypoints {
	// we never remove tracks, this just enables automatic KVO
	(void)oldWaypoints;
	[self doesNotRecognizeSelector:_cmd];
}

- (BOOL)isExporting {
	return !!exportController;
}

- (id)initWithTracks:(NSArray*)theTracks {
	self = [super init];
	if (self) {
		tracks = [[NSMutableSet setWithArray:theTracks] retain];
		waypoints = [NSMutableSet new];
		[NSBundle loadNibNamed:@"Project" owner:self];
	}
	return self;
}

- (void)awakeFromNib {
	[window setDelegate:self];
	
	[self fitMapViewToTracks];
	
	TLNaturalEarthLayer* landcover = [[TLNaturalEarthLayer new] autorelease];
	[mapView addLayer:landcover];
	TLGraticuleMapLayer* gridLines = [[TLGraticuleMapLayer new] autorelease];
	[mapView addLayer:gridLines];
	
	[mapView addLayer:[metadataController locationLayer]];
	[mapView addLayer:[metadataController itemLayer]];
	
	TLMapBevel* bevelLayer = [[TLMapBevel new] autorelease];
	[mapView addLayer:bevelLayer];
	
	[metadataController bind:@"itemSource"
					toObject:sourceController
				 withKeyPath:@"source"
					 options:nil];
	
	// TODO: ensure binding both ways is kosher, then make tlDoubleBind category
	[metadataController bind:@"cameraError"
					toObject:offsetController
				 withKeyPath:@"cameraError"
					 options:nil];
	[offsetController bind:@"cameraError"
					toObject:metadataController
				 withKeyPath:@"cameraError"
					 options:nil];
	
	[metadataController bind:@"cameraTimeZone"
					toObject:offsetController
				 withKeyPath:@"cameraTimeZone"
					 options:nil];
}

- (void)dealloc {
	[metadataController unbind:@"itemSource"];
	[metadataController unbind:@"cameraError"];
	[offsetController unbind:@"cameraError"];
	[metadataController unbind:@"cameraTimeZone"];
	[window setDelegate:nil];
	[window release];
	[sourceController release];
	[offsetController release];
	[metadataController release];
	[tracks release];
	[waypoints release];
	NSAssert(!exportController, @"Project controller deallocated with outstanding export");
	[super dealloc];
}


#pragma mark Data source

- (void)fitMapViewToTracks {
	if (![[self tracks] count]) return;
	
	// TODO: find spherical centroid of convex hull around all track points
	
	// find bounds in ECE for now
	CGRect trackBounds = CGRectNull;
	for (TLTrack* track in [self tracks]) {
		for (TLWaypoint* waypoint in [track waypoints]) {
			TLCoordinate coord = [[waypoint location] coordinate];
			CGPoint ecePoint = CGPointMake((CGFloat)coord.lon, (CGFloat)coord.lat);
			trackBounds = TLCGRectExpandToIncludePoint(trackBounds, ecePoint);
		}
	}
	CGPoint eceCenter = TLCGRectGetCenter(trackBounds);
	TLProjectionRef proj = TLProjectionCreateStereographicWithCenter(eceCenter.y, eceCenter.x);
	if (!proj) {
		NSLog(@"Could not zoom in around track (Projection center: %f, %f)", eceCenter.y, eceCenter.x);
		return;
	}
	
	CGRect mapBounds = CGRectNull;
	for (TLTrack* track in [self tracks]) {
		for (TLWaypoint* waypoint in [track waypoints]) {
			TLCoordinate coord = [[waypoint location] coordinate];
			TLProjectionError err = TLProjectionErrorNone;
			CGPoint point = TLProjectionProjectCoordinate(proj, coord, &err);
			if (err) {
				NSLog(@"Error projecting track point.");
				continue;
			}
			mapBounds = TLCGRectExpandToIncludePoint(mapBounds, point);
		}
	}
	
	if (CGRectGetWidth(mapBounds) < 5.0f) {
		mapBounds.size.width = 5.0f;
	}
	if (CGRectGetHeight(mapBounds) < 5.0f) {
		mapBounds.size.height = 5.0f;
	}
	
	CGFloat padRatio = 0.1f;
	mapBounds = CGRectInset(mapBounds,
							-padRatio * CGRectGetWidth(mapBounds),
							-padRatio * CGRectGetHeight(mapBounds));
	
	[mapView setDesiredBounds:mapBounds];
	[mapView setProjection:proj];
	TLProjectionRelease(proj);
}

- (void)windowWillClose:(NSNotification*)theNotification {
	NSWindow* theWindow = [theNotification object];
	if (theWindow != window) return;
	[sourceController setSource:nil];
	[metadataController setLocationSource:nil];
}


#pragma mark Export controller handling

- (void)exportDidFinish:(ExportController*)theExportController {
	if ([[theExportController warnings] count]) {
		NSDictionary* errInfo = [NSDictionary dictionaryWithObjectsAndKeys:
								 @"Some photos were not geotagged. "
								 @"This may happen with movie files, or "
								 @"if files are in an unsupported RAW format.",
								 NSLocalizedDescriptionKey, nil];
		[NSApp presentError:[NSError errorWithDomain:@"com.calftrail.tagalog" code:42 userInfo:errInfo]];
	}
	[exportController release];
	exportController = nil;
	
	CFNumberRef geolookup = CFPreferencesCopyValue(CFSTR("GeocodeLookupPreference"), CFSTR("com.apple.iPhoto"),
												   kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
	if (geolookup) {
		if ([(id)geolookup intValue] != 2) {	// 0 - never lookup, 1 - not set, 2 - automatically
			NSDictionary* errInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									 @"iPhoto will not show your photos on its map", NSLocalizedDescriptionKey,
									 @"Before its Places feature will work, you must go into iPhoto's preferences "
									 @"and, in the Advanced tab, set \"Look up Places\" to \"Automatically\".",
									 NSLocalizedRecoverySuggestionErrorKey, nil];
			NSError* lookupSettingError = [NSError errorWithDomain:@"com.calftrail.tagalog" code:1000 userInfo:errInfo];
			[NSApp presentError:lookupSettingError];
		}
		CFRelease(geolookup);
	}
	
	[window close];
}

- (void)exportDidCancel:(ExportController*)theExportController {
	(void)theExportController;
	[exportController release];
	exportController = nil;
}

- (void)exportDidFail:(ExportController*)theExportController
			withError:(NSError*)err
{
	(void)theExportController;
	[NSApp presentError:err];
	[exportController release];
	exportController = nil;
}


#pragma mark Action methods

- (IBAction)beginExport:(id)sender {
	(void)sender;
	NSSet* allItems = (NSSet*)[[sourceController source] items];
	NSSet* taggedItems = TLNSMapTableAllKeys([metadataController itemMetadata]);
	NSMutableSet* copiedItems = [NSMutableSet set];
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ExportAllItems"]) {
		[copiedItems unionSet:allItems];
		[copiedItems minusSet:taggedItems];
	}
	
	NSMapTable* taggedMetadata = [metadataController itemMetadata];
	id registrar = [TLJimBos sharedRegistrar];
	if (![registrar isRegistered]) {
		const NSUInteger exportLimit = 24;
		NSSet* exportItems = [taggedItems setByAddingObjectsFromSet:copiedItems];
		if ([exportItems count] > exportLimit) {
			if ([registrar continueExportDemoPrompt]) {
				NSArray* shuffledPhotos = TLNSArrayShuffle([exportItems allObjects]);
				NSMutableSet* reducedExportPhotos = [NSMutableSet setWithCapacity:exportLimit];
				for (NSUInteger photoIdx = 0; photoIdx < exportLimit; ++photoIdx) {
					id photo = [shuffledPhotos objectAtIndex:photoIdx];
					[reducedExportPhotos addObject:photo];
				}
				
				for (TLPhotoSourceItem* item in taggedItems) {
					if (![reducedExportPhotos containsObject:item]) {
						[taggedMetadata removeObjectForKey:item];
					}
				}
				[copiedItems intersectSet:exportItems];
			}
			else {
				return;
			}
		}
	}
	
	exportController = [iPhotoExportController new];
	[exportController setDelegate:self];
	[exportController setWindow:window];
	[exportController setCopiedItems:copiedItems];
	[exportController setItemsWithMetadata:taggedMetadata];
	[exportController export];
}

@end


TLProjectionRef TLProjectionCreateStereographicWithCenter(TLCoordinateDegrees lat,
														  TLCoordinateDegrees lon)
{
	TLMutableProjectionParametersRef params = TLProjectionParametersCreateMutable();
	TLProjectionParametersSetLongitudeOfOrigin(params, lon);
	TLProjectionParametersSetLatitudeOfOrigin(params, lat);
	TLProjectionRef proj =  TLProjectionCreate(TLProjectionNameStereographic, TLProjectionGeoidWGS84, params, NULL);
	TLProjectionParametersRelease(params);
	return proj;
}


