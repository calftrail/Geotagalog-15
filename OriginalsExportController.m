//
//  OriginalsExportController.m
//  Tagalog
//
//  Created by Nathan Vander Wilt on 5/13/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "OriginalsExportController.h"

#import "TLPhoto.h"


@implementation OriginalsExportController

- (BOOL)prepareForExport:(NSError**)err {
	(void)err;
	return YES;
}

- (BOOL)exportItem:(TLPhoto*)photo error:(NSError**)err {
	(void)photo;
	(void)err;
	
	// TODO: geotag original
	
	// TODO: add to "reload" album if in iPhoto
	
	return YES;
}

- (void)cancelExport {
	
}

- (BOOL)finishExport:(NSError**)err {
	(void)err;
	return YES;
}

@end
