//
//  TLFileSourceItem.m
//  Tagalog
//
//  Created by Nathan Vander Wilt on 6/5/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "TLFileSourceItem.h"

#import "TLFilePhotoSource.h"

#import "TLCocoaToolbag.h"
#import "NSFileManager+TLExtensions.h"
#import "TLLocation.h"
#import "TLTimestamp.h"


extern NSDateFormatter* TLPhotoSourceExifTimestampParser(void);
extern BOOL TLPhotoAddMetadata(NSURL* originalURL, NSURL* targetURL,
							   NSDictionary* metadata, NSError** err);


@interface TLFileSourceItem ()
@property (nonatomic, readwrite, copy) NSString* filePath;
@property (nonatomic, copy) NSString* fileUTI;
@property (nonatomic, copy) NSDictionary* metadata;
@property (nonatomic, readonly) CGImageSourceRef imageSource;
- (void)updateWithProperties:(NSDictionary*)theProperties;
@end


@implementation TLFileSourceItem

@synthesize filePath;
@synthesize fileUTI;
@synthesize metadata;
@synthesize imageSource;


- (id)initWithSource:(TLFilePhotoSource*)source
			filePath:(NSString*)theFilePath
			   error:(NSError**)err
{
	self = [super initWithSource:source];
	if (self) {
		NSURL* fileURL = [NSURL fileURLWithPath:theFilePath isDirectory:NO];
		NSString* theUTI = TLFileGetUTI(fileURL);
		[self setFileUTI:theUTI];
		
		CGImageSourceRef theImageSource = NULL;
		if (UTTypeConformsTo((CFStringRef)theUTI, kUTTypeImage)) {
			NSDictionary* sourceOptions = [NSDictionary dictionaryWithObjectsAndKeys:
										   theUTI, (id)kCGImageSourceTypeIdentifierHint, nil];
			theImageSource = CGImageSourceCreateWithURL((CFURLRef)fileURL,
														(CFDictionaryRef)sourceOptions);
		}
		
		if (theImageSource && !CGImageSourceGetCount(theImageSource)) {
			CFRelease(theImageSource);
			[super dealloc];
			if (err) {
				NSDictionary* errInfo = [NSDictionary dictionaryWithObjectsAndKeys:
										 theFilePath, NSFilePathErrorKey, nil];
				*err = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadCorruptFileError userInfo:errInfo];
			}
			return nil;
		}
		
		if (theImageSource) {
			CFDictionaryRef imgProperties = CGImageSourceCopyPropertiesAtIndex(theImageSource, 0, NULL);
			if (imgProperties) {
				[self updateWithProperties:(NSDictionary*)imgProperties];
				CFRelease(imgProperties);
			}
		}
		
		imageSource = theImageSource;
		[self setFilePath:theFilePath];
	}
	return self;
}

- (void)dealloc {
	[self setFilePath:nil];
	[self setFileUTI:nil];
	[self setMetadata:nil];
	if (imageSource) CFRelease(imageSource), imageSource = NULL;
	[super dealloc];
}


- (void)updateWithProperties:(NSDictionary*)theProperties {
	//NSLog(@"%@", theProperties);
	NSMutableDictionary* theMetadata = [[[self metadata] mutableCopy] autorelease];
	if (!theMetadata) {
		theMetadata = [NSMutableDictionary dictionary];
	}
	
	NSString* timestampString = [[theProperties objectForKey:(id)kCGImagePropertyExifDictionary]
								 objectForKey:(id)kCGImagePropertyExifDateTimeOriginal];
	if (!timestampString) {
		timestampString = [[theProperties objectForKey:(id)kCGImagePropertyExifDictionary]
						   objectForKey:(id)kCGImagePropertyExifDateTimeDigitized];
		if (!timestampString) {
			timestampString = [[theProperties objectForKey:(id)kCGImagePropertyTIFFDictionary]
							   objectForKey:(id)kCGImagePropertyTIFFDateTime];
		}
	}
	
	NSDate* itemDate = nil;
	if (timestampString) {
		NSDateFormatter* timestampParser = TLPhotoSourceExifTimestampParser();
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
	// NOTE: we don't currently pay attention to which types ExifTool can actually tag
	return UTTypeConformsTo((CFStringRef)[self fileUTI], kUTTypeImage);
}

- (NSString*)originalFilename {
	return [[self filePath] lastPathComponent];
}

+ (CFDictionaryRef)thumbnailOptionsForSize:(CGFloat)size {
	NSDictionary* options = [NSDictionary dictionaryWithObjectsAndKeys:
							 (id)kCFBooleanTrue, (id)kCGImageSourceCreateThumbnailFromImageAlways,
							 [NSNumber numberWithDouble:size], (id)kCGImageSourceThumbnailMaxPixelSize,
							 (id)kCFBooleanTrue, (id)kCGImageSourceCreateThumbnailWithTransform, nil];
	return (CFDictionaryRef)options;
}

- (CGImageRef)newThumbnailForSize:(CGFloat)approximateSize
						  options:(NSDictionary*)options
							error:(NSError**)err
{
	(void)approximateSize;
	(void)options;
	
	if (![self imageSource]) {
		if (err) {
			*err = [NSError errorWithDomain:NSCocoaErrorDomain
									   code:NSFileReadCorruptFileError
								   userInfo:nil];
		}
		return NULL;
	}
	
	CFDictionaryRef thumbnailOptions = [[self class] thumbnailOptionsForSize:approximateSize];
	CGImageRef thumbnail = CGImageSourceCreateThumbnailAtIndex([self imageSource], 0, thumbnailOptions);
	if (!thumbnail && err) {
		*err = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadCorruptFileError userInfo:nil];
	}
	return thumbnail;
}

- (BOOL)exportToPath:(NSURL*)path
			metadata:(NSDictionary*)theMetadata
			 options:(NSDictionary*)options
			   error:(NSError**)err
{
	(void)options;
	if (theMetadata) {
		return TLPhotoAddMetadata([NSURL fileURLWithPath:[self filePath] isDirectory:NO], path,
								  theMetadata, err);
	}
	else {
		return [[NSFileManager tlThreadManager] copyItemAtPath:[self filePath]
														toPath:[path path]
														 error:err];
	}
}

@end


BOOL TLPhotoAddMetadata(NSURL* originalURL, NSURL* targetURL,
						NSDictionary* metadata, NSError** err)
{
	TLLocation* location = [metadata objectForKey:TLMetadataLocationKey];
	TLTimestamp* timestamp = [metadata objectForKey:TLMetadataTimestampKey];
	NSTimeZone* timeZone = [metadata objectForKey:TLMetadataTimezoneKey];
	
	if (!targetURL) {
		targetURL = originalURL;
	}
	
	// copy original file to target path
	if (![targetURL isEqualTo:originalURL]) {
		NSFileManager* fileManager = [[NSFileManager new] autorelease];
		BOOL itemCopied = [fileManager copyItemAtPath:[originalURL path] toPath:[targetURL path] error:err];
		if (!itemCopied) return NO;
	}
	
	NSMutableArray* exifToolArgs = [NSMutableArray array];
	
	// remove any existing location metadata, so as to not to merge two different sets of values
	[exifToolArgs addObject:@"-GPS:all="];
	
	// add location (datum, lat/lon/altitude+refs)
	[exifToolArgs addObject:@"-GPSMapDatum=WGS-84"];
	TLCoordinate coord = [location coordinate];
	[exifToolArgs addObject:[NSString stringWithFormat:@"-GPSLatitude=%f", fabs(coord.lat)]];
	[exifToolArgs addObject:[NSString stringWithFormat:@"-GPSLatitudeRef=%c", (coord.lat < 0.0 ? 'S' : 'N')]];
	[exifToolArgs addObject:[NSString stringWithFormat:@"-GPSLongitude=%f", fabs(coord.lon)]];
	[exifToolArgs addObject:[NSString stringWithFormat:@"-GPSLongitudeRef=%c", (coord.lon < 0.0 ? 'W' : 'E')]];
	TLCoordinateAltitude altitude = [location altitude];
	if (altitude != TLCoordinateAltitudeUnknown) {
		[exifToolArgs addObject:[NSString stringWithFormat:@"-GPSAltitude=%f", fabs(altitude)]];
		[exifToolArgs addObject:[NSString stringWithFormat:@"-GPSAltitudeRef=%c", (altitude < 0.0 ? '1' : '0')]];
	}
	// TODO: set GPSDOP if possible
	
	// add original time, adjusted for time zone
	NSDate* photoDate = [timestamp time];
	NSTimeInterval offset = [timeZone secondsFromGMTForDate:photoDate];
	NSDate* adjustedDate = [photoDate addTimeInterval:offset];
	NSDateFormatter* exifFormat = [[NSDateFormatter new] autorelease];
	NSCalendar* gregorian = [[[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar] autorelease];
	[exifFormat setCalendar:gregorian];
	[exifFormat setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
	[exifFormat setDateFormat:@"yyyy:MM:dd HH:mm:ss"];
	NSString* dateString = [exifFormat stringFromDate:adjustedDate];
	[exifToolArgs addObject:[NSString stringWithFormat:@"-DateTimeOriginal=%@", dateString]];
	// TODO: add subseconds when available
	
	// set software name
	NSDictionary* appInfo = [[NSBundle mainBundle] infoDictionary];
	NSString* appName = [appInfo objectForKey:(id)kCFBundleNameKey];
	NSString* appVersion = [appInfo objectForKey:@"CFBundleShortVersionString"];
	NSString* fullAppName = [NSString stringWithFormat:@"%@ v%@", appName, appVersion];
	[exifToolArgs addObject:[NSString stringWithFormat:@"-Software=%@", fullAppName]];
	
	[exifToolArgs addObject:@"-overwrite_original"];	// @"-overwrite_original_in_place" (slower, retains extended attributes)
	[exifToolArgs addObject:@"-n"];
	[exifToolArgs addObject:@"-q"];
	[exifToolArgs addObject:[targetURL path]];
	
	//NSLog(@"%@", exifToolArgs);
	NSString* exifToolPath = [[NSBundle mainBundle] pathForResource:@"exiftool" ofType:nil];
	NSTask* exifToolTask = [NSTask launchedTaskWithLaunchPath:exifToolPath arguments:exifToolArgs];
	[exifToolTask waitUntilExit];
	int taskResult = [exifToolTask terminationStatus];
	if (taskResult) {
		if (err) {
			NSMutableDictionary* errInfo = [NSMutableDictionary dictionary];
			[errInfo setObject:@"Could not add geotag to image"
						forKey:NSLocalizedDescriptionKey];
			[errInfo setObject:@"This is most likely to occur if your image was in an unsupported RAW format"
						forKey:NSLocalizedFailureReasonErrorKey];
			[errInfo setObject:[[originalURL path] lastPathComponent]
						forKey:NSFilePathErrorKey];
			*err = [NSError errorWithDomain:@"com.calftrail.tagalog" code:-40 userInfo:errInfo];
		}
		return NO;
	}
	
	return YES;
}
