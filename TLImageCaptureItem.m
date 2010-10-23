//
//  TLImageCaptureItem.m
//  Tagalog
//
//  Created by Nathan Vander Wilt on 6/2/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "TLImageCaptureItem.h"

#include "TLImageCapture.h"
#import "TLImageCapturePhotoSource.h"

#import "TLTimestamp.h"

extern NSDateFormatter* TLPhotoSourceExifTimestampParser(void);
extern CGImageRef TLPhotoSourceCreateBlankImage(void);
extern BOOL TLPhotoAddMetadata(NSURL* originalURL, NSURL* targetURL,
							   NSDictionary* metadata, NSError** err);

// denotes location of 0-th row, 0-th column
typedef enum {
	TLImageOrientationTopLeft = 1,		// default orientation
	UIImageOrientationTopRight,			// flip horizontally (across |)
	TLImageOrientationBottomRight,		// rotate 180 deg
	TLImageOrientationBottomLeft,		// flip vertically (across -)
	TLImageOrientationLeftTop,			// rotate right, then flip vertically
	TLImageOrientationRightTop,			// rotate right (90 deg CW)
	TLImageOrientationRightBottom,		// rotate left, then flip vertically
	TLImageOrientationLeftBottom		// rotate left (90 deg CCW)
} TLImageOrientation;

static CGImageRef TLCGImageCreateOriented(CGImageRef srcImg, TLImageOrientation orientation);


@interface TLImageCaptureItem ()
@property (nonatomic, assign) TLICAObject icao;
@property (nonatomic, assign) UInt32 fileType;
@property (nonatomic, copy) NSString* originalFilename;
@property (nonatomic, copy) NSDictionary* metadata;
- (void)updateWithInfo:(NSDictionary*)theInfo;
@end


@implementation TLImageCaptureItem

@synthesize icao;
@synthesize fileType;
@synthesize metadata;
@synthesize originalFilename;

-(id)initWithSource:(TLImageCapturePhotoSource*)theSource
			   info:(NSDictionary*)theInfo
{
	self = [super initWithSource:theSource];
	if (self) {
		//NSLog(@"%@", theInfo);
		TLICAObject theIcao = [[theInfo objectForKey:(id)kTLICAObjectKey] intValue];
		[self setIcao:theIcao];
		[self updateWithInfo:theInfo];
	}
	return self;
}

- (void)dealloc {
	[self setOriginalFilename:nil];
	[self setMetadata:nil];
	[super dealloc];
}

- (void)updateWithInfo:(NSDictionary*)theInfo {
	NSString* theFilename = [theInfo objectForKey:(id)kTLICAObjectNameKey];
	if (theFilename) {
		[self setOriginalFilename:theFilename];
	}
	
	NSNumber* itemType = [theInfo objectForKey:(id)kTLICAFileTypeKey];
	if (itemType) {
		[self setFileType:[itemType intValue]];
	}
	
	NSMutableDictionary* theMetadata = [[[self metadata] mutableCopy] autorelease];
	if (!theMetadata) {
		theMetadata = [NSMutableDictionary dictionary];
	}
	
	NSDate* itemDate = nil;
	NSDateFormatter* timestampParser = TLPhotoSourceExifTimestampParser();
	NSString* timestampString = [theInfo objectForKey:(id)kTLICAImageDateOriginalKey];
	if (timestampString) {
		itemDate = [timestampParser dateFromString:timestampString];
	}
	else {
		timestampString = [theInfo objectForKey:(id)kTLICAImageDateDigitizedKey];
		itemDate = [timestampParser dateFromString:timestampString];
	}
	if (itemDate) {
		TLTimestamp* timestamp = [TLTimestamp timestampWithTime:itemDate
													   accuracy:TLTimestampAccuracyUnknown];
		[theMetadata setObject:timestamp forKey:TLMetadataTimestampKey];
	}
	
	[self setMetadata:theMetadata];
}

- (BOOL)canGeotag {
	return ([self fileType] == kICAFileImage);
}

- (CGImageRef)newThumbnailForSize:(CGFloat)approximateSize
						  options:(NSDictionary*)options
							error:(NSError**)err
{
	(void)approximateSize;
	(void)options;
	(void)err;
	
	CFDataRef thumbnailData = NULL;
	ICACopyObjectThumbnailPB copyThumbnailPB = {};
	copyThumbnailPB.object = [self icao];
	copyThumbnailPB.thumbnailFormat = kICAThumbnailFormatJPEG;
	copyThumbnailPB.thumbnailData = &thumbnailData;
	ICAError internalErrCode = TLICACopyObjectThumbnail(&copyThumbnailPB, NULL);
	if (internalErrCode) {
		if (err) {
			*err = [NSError errorWithDomain:NSOSStatusErrorDomain code:internalErrCode userInfo:nil];
		}
		return NULL;
	}
	
	// fetch the object's properties so we can display thumbnails properly (see note below)
	CFDictionaryRef objectProperties = NULL;
	ICACopyObjectPropertyDictionaryPB copyPropertiesPB = {};
	copyPropertiesPB.object = [self icao];
	copyPropertiesPB.theDict = &objectProperties;
	internalErrCode = TLICACopyObjectPropertyDictionary(&copyPropertiesPB, NULL);
	if (internalErrCode) {
		if (err) {
			*err = [NSError errorWithDomain:NSOSStatusErrorDomain code:internalErrCode userInfo:nil];
		}
		return NULL;
	}
	NSNumber* orientationValue = (id)CFDictionaryGetValue(objectProperties, kTLICAImageOrientationKey);
	CFRelease(objectProperties);
	
	CGImageRef thumbnail = NULL;
	CGImageSourceRef thumbnailSource = CGImageSourceCreateWithData(thumbnailData, NULL);
	CFRelease(thumbnailData);
	if (thumbnailSource) {
		if (CGImageSourceGetCount(thumbnailSource)) {
			thumbnail = CGImageSourceCreateImageAtIndex(thumbnailSource, 0, NULL);
			/* NOTE: ICA does not autorotate thumbnail rdar://problem/6959922
			 So we must rotate it ourselves. */
			if (orientationValue) {
				TLImageOrientation orientation = [orientationValue unsignedIntValue];
				CGImageRef orientedThumbnail = TLCGImageCreateOriented(thumbnail, orientation);
				CGImageRelease(thumbnail);
				thumbnail = orientedThumbnail;
			}
		}
		CFRelease(thumbnailSource);
	}
	if (!thumbnail && err) {
		*err = [NSError errorWithDomain:NSOSStatusErrorDomain code:readErr userInfo:nil];
	}
	return thumbnail;
}

- (BOOL)exportToPath:(NSURL*)outputLocation
			metadata:(NSDictionary*)theMetadata
			 options:(NSDictionary*)options
			   error:(NSError**)err;
{
	(void)outputLocation;
	(void)theMetadata;
	(void)options;
	(void)err;
	
	FSRef downloadHostFolder = {};
	NSString* outputFolder = [[outputLocation path] stringByDeletingLastPathComponent];
	NSURL* outputFolderURL = [NSURL fileURLWithPath:outputFolder isDirectory:YES];
	Boolean success = CFURLGetFSRef((CFURLRef)outputFolderURL, &downloadHostFolder);
	if (!success) {
		if (err) {
			*err = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadUnknownError userInfo:nil];
		}
		return NO;
	}	
	
	/* NOTE: if large file cancellation is desired in the future,
	 or finer control of output location, check out ICACopyObjectData() */
	FSRef downloadedFile = {};
	ICADownloadFilePB downloadFilePB = {};
	downloadFilePB.object = [self icao];
	downloadFilePB.flags = kAdjustCreationDate;
	downloadFilePB.dirFSRef = &downloadHostFolder;
	downloadFilePB.fileFSRef = &downloadedFile;
	ICAError internalErrCode = TLICADownloadFile(&downloadFilePB, NULL);
	if (internalErrCode) {
		if (err) {
			*err = [NSError errorWithDomain:NSOSStatusErrorDomain code:internalErrCode userInfo:nil];
		}
		return NO;
	}
	
	// rename downloaded file to target, and geotag
	NSURL* downloadedURL = [(id)CFURLCreateFromFSRef(kCFAllocatorDefault, &downloadedFile) autorelease];
	// NOTE: this assumes download was to same FS volume as output location
	int errCode = rename([[downloadedURL path] fileSystemRepresentation],
						 [[outputLocation path] fileSystemRepresentation]);
	if (errCode) {
		if (err) {
			NSDictionary* errInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									 [outputLocation path], NSFilePathErrorKey, nil];
			*err = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:errInfo];
		}
		return NO;
	}
	
	if (theMetadata) {
		return TLPhotoAddMetadata(outputLocation, nil, theMetadata, err);
	}
	else {
		return YES;	
	}
}

@end

NSDateFormatter* TLPhotoSourceExifTimestampParser() {
	NSMutableDictionary* threadInfo = [[NSThread currentThread] threadDictionary];
	static NSString* const parserKey = @"com.tagalog.photosource.exifTimestampParser";
	NSDateFormatter* exifTimestampParser = [threadInfo objectForKey:parserKey];
	if (!exifTimestampParser) {
		exifTimestampParser = [[NSDateFormatter new] autorelease];
		[exifTimestampParser setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
		NSCalendar* gregorian = [[[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar] autorelease];
		[exifTimestampParser setCalendar:gregorian];
		[exifTimestampParser setDateFormat:@"yyyy:MM:dd HH:mm:ss"];
		[threadInfo setObject:exifTimestampParser forKey:parserKey];
	}
	return exifTimestampParser;
}

CGImageRef TLCGImageCreateOriented(CGImageRef srcImg, TLImageOrientation orientation) {
	// Only handle common rotations (for now). See http://www.gotow.net/creative/wordpress/?p=64
	CGSize srcSize = CGSizeMake(CGImageGetWidth(srcImg), CGImageGetHeight(srcImg));
	CGAffineTransform drawTransform = CGAffineTransformIdentity;
	BOOL flipAspect = NO;
	switch (orientation) {
		default:
		case TLImageOrientationTopLeft:
			return CGImageRetain(srcImg);
		case TLImageOrientationBottomRight:
			drawTransform = CGAffineTransformMakeTranslation(srcSize.width, srcSize.height);
			drawTransform = CGAffineTransformRotate(drawTransform, (CGFloat)M_PI);
			break;
		case TLImageOrientationRightTop:
			drawTransform = CGAffineTransformMakeTranslation(0.0f, srcSize.width);
			drawTransform = CGAffineTransformRotate(drawTransform, (CGFloat)-M_PI_2);
			flipAspect = YES;
			break;
		case TLImageOrientationLeftBottom:
			drawTransform = CGAffineTransformMakeTranslation(srcSize.height, 0.0f);
			drawTransform = CGAffineTransformRotate(drawTransform, (CGFloat)M_PI_2);
			flipAspect = YES;
			break;
	}
	
	CGSize targetSize = (flipAspect ?
						  CGSizeMake(CGImageGetHeight(srcImg), CGImageGetWidth(srcImg)) :
						  CGSizeMake(CGImageGetWidth(srcImg), CGImageGetHeight(srcImg)));
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGContextRef ctx = CGBitmapContextCreate(NULL, targetSize.width, targetSize.height,
											 8, (size_t)targetSize.width * 4,
											 space, kCGImageAlphaPremultipliedFirst);
	CGColorSpaceRelease(space);
	NSCAssert(ctx, @"Couldn't create image flipping context");
	
	CGContextConcatCTM(ctx, drawTransform);
	CGContextDrawImage(ctx, (CGRect){.origin = CGPointZero, .size = srcSize}, srcImg);
	CGImageRef img = CGBitmapContextCreateImage(ctx);
	CGContextRelease(ctx);
	return img;
}
