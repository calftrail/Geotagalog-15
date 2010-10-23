//
//  FolderExportController.h
//  Tagalog
//
//  Created by Nathan Vander Wilt on 5/13/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ExportController.h"


@interface FolderExportController : ExportController {
@private
	NSString* folder;
	NSMutableArray* mutableExportedPaths;
}

@property (nonatomic, copy) NSString* folder;
@property (nonatomic, readonly) NSArray* exportedPaths;

@end
