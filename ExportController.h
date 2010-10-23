//
//  ExportController.h
//  Tagalog
//
//  Created by Nathan Vander Wilt on 5/13/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TLPhotoSourceItem;

@interface ExportController : NSObject {
	IBOutlet NSWindow* exportSheet;
	__weak IBOutlet NSTextField* progressText;
	__weak IBOutlet NSProgressIndicator* progressMeter;
	__weak IBOutlet NSButton* cancelButton;
@private
	id delegate;
	NSWindow* window;
	NSSet* copiedItems;
	NSMapTable* itemsWithMetadata;
	BOOL shouldCancel;
	NSMutableSet* warnings;
}

@property (nonatomic, assign) id delegate;
@property (nonatomic, assign) NSWindow* window;
@property (nonatomic, copy) NSSet* copiedItems;
@property (nonatomic, copy) NSMapTable* itemsWithMetadata;

@property (nonatomic, readonly) NSSet* warnings;

- (void)export;
- (IBAction)cancel:(id)sender;

// for subclass implementation
- (BOOL)prepareForExport:(NSError**)err;
- (BOOL)exportItem:(TLPhotoSourceItem*)item
	  withMetadata:(NSDictionary*)metadata
			 error:(NSError**)err;
- (BOOL)copyItem:(TLPhotoSourceItem*)item
		   error:(NSError**)err;
- (void)cancelExport;
- (BOOL)finishExport:(NSError**)err;

- (void)noteWarning:(NSError*)warning;

@end

@interface NSObject (ExportControllerDelegate)
- (void)exportDidFinish:(ExportController*)theExportController;
- (void)exportDidCancel:(ExportController*)theExportController;
- (void)exportDidFail:(ExportController*)theExportController
			withError:(NSError*)err;
@end
