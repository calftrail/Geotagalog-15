//
//  TLGPXWaypoint.m
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 3/17/08.
//  Copyright 2008 Calf Trail Software, LLC. All rights reserved.
//

#import "TLGPXWaypoint.h"

NSDate* TLNSDateFromStandardString(NSString* str);

@implementation TLGPXWaypoint

- (id)initWithParent:(TLGPXNode*)theParent
		  forElement:(NSString*)elementName
		namespaceURI:(NSString*)namespaceURI
	   qualifiedName:(NSString*)qualifiedName
		  attributes:(NSDictionary*)attributes
{
	self = [super initWithParent:theParent
					  forElement:elementName
					namespaceURI:namespaceURI
				   qualifiedName:qualifiedName
					  attributes:attributes];
	if (self) {
		coordinate.lat = [[attributes valueForKey:@"lat"] doubleValue];
		coordinate.lon = [[attributes valueForKey:@"lon"] doubleValue];
		elevation = TLCoordinateAltitudeUnknown;
	}
	return self;
}

- (void)dealloc {
	[time release];
	[name release];
	[super dealloc];
}


#pragma mark Parsing out of XML

- (void)parser:(NSXMLParser*)parser didStartElement:(NSString*)elementName
  namespaceURI:(NSString*)namespaceURI
 qualifiedName:(NSString*)qualifiedName
	attributes:(NSDictionary*)attributeDict
{
	(void)parser;
	(void)namespaceURI;
	(void)qualifiedName;
	(void)attributeDict;
	if ([elementName isEqualToString:@"time"] ||
		[elementName isEqualToString:@"name"] ||
		[elementName isEqualToString:@"ele"] ||
		[elementName isEqualToString:@"hdop"] ||
		[elementName isEqualToString:@"vdop"] ||
		[elementName isEqualToString:@"pdop"])
	{
		[self setGatheringCharacters:YES];
	}
}

NSDate* TLNSDateFromStandardString(NSString* str) {
	NSCParameterAssert(str != nil);
	/* Parse xsd:dateTime http://www.w3.org/TR/xmlschema-2/#dateTime in an accepting manner.
	 '-'? yyyy '-' mm '-' dd 'T' hh ':' mm ':' ss ('.' s+)? ((('+' | '-') hh ':' mm) | 'Z')?
	 Note that yyyy may be negative, or more than 4 digits.
	 When a timezone is added to a UTC dateTime, the result is the date and time "in that timezone". */
	int year = 0;
	unsigned int month = 0, day = 0, hours = 0, minutes = 0;
	double seconds = 0.0;
	char timeZoneBuffer[7] = "";
	int numFieldsParsed = sscanf([str UTF8String], "%d-%u-%u T %u:%u:%lf %6s",
								 &year, &month, &day, &hours, &minutes, &seconds, timeZoneBuffer);
	if (numFieldsParsed < 6) {
		return nil;
	}
	
	int timeZoneSeconds = 0;
	if (timeZoneBuffer[0] && timeZoneBuffer[0] != 'Z') {
		int tzHours = 0;
		unsigned int tzMinutes = 0;
		int numTimezoneFieldsParsed = sscanf(timeZoneBuffer, "%d:%ud", &tzHours, &tzMinutes);
		if (numTimezoneFieldsParsed < 2) {
			return nil;
		}
		timeZoneSeconds = 60 * (tzMinutes + (60 * abs(tzHours)));
		if (tzHours < 0) {
			timeZoneSeconds = -timeZoneSeconds;
		}
	}
	
	NSDateComponents* parsedComponents = [[NSDateComponents new] autorelease];
	[parsedComponents setYear:year];
	[parsedComponents setMonth:month];
	[parsedComponents setDay:day];
	[parsedComponents setHour:hours];
	[parsedComponents setMinute:minutes];
	
	// NOTE: I don't know how exactly this calendar deals with negative years, or the transition from Julian
	NSCalendar* gregorian = [[[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar] autorelease];
	[gregorian setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:timeZoneSeconds]];
	NSDate* dateWithoutSeconds = [gregorian dateFromComponents:parsedComponents];
	NSDate* date = [dateWithoutSeconds addTimeInterval:seconds];
	//printf("'%s' yielded %s\n", [str UTF8String], [[date description] UTF8String]);
	return date;
}

- (void)parser:(NSXMLParser*)parser didEndElement:(NSString*)elementName
  namespaceURI:(NSString*)namespaceURI
 qualifiedName:(NSString*)qualifiedName
{
	if ([elementName isEqualToString:@"time"]) {
		time = [TLNSDateFromStandardString([self gatheredCharacters]) copy];
		if (!time) NSLog(@"Could not convert string '%@' to a date!", [self gatheredCharacters]);
		[self setGatheringCharacters:NO];
	}
	else if ([elementName isEqualToString:@"ele"]) {
		elevation = [[self gatheredCharacters] doubleValue];
		[self setGatheringCharacters:NO];
	}
	else if ([elementName isEqualToString:@"name"]) {
		name = [[self gatheredCharacters] copy];
		[self setGatheringCharacters:NO];
	}
	else if ([elementName isEqualToString:@"hdop"]) {
		horizontalDOP = [[self gatheredCharacters] doubleValue];
		[self setGatheringCharacters:NO];
	}
	else if ([elementName isEqualToString:@"vdop"]) {
		verticalDOP = [[self gatheredCharacters] doubleValue];
		[self setGatheringCharacters:NO];
	}
	else if ([elementName isEqualToString:@"pdop"]) {
		positionDOP = [[self gatheredCharacters] doubleValue];
		[self setGatheringCharacters:NO];
	}
	else {
		[super parser:parser didEndElement:elementName namespaceURI:namespaceURI qualifiedName:qualifiedName];
	}
}


#pragma mark Accessors

@synthesize name;
@synthesize time;
@synthesize coordinate;
@synthesize elevation;
@synthesize horizontalDOP;
@synthesize verticalDOP;
@synthesize positionDOP;

@end
