//
//  TLTagalogAppDelegate.h
//  Tagalog
//
//  Created by Nathan Vander Wilt on 1/23/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface TLTagalogAppDelegate : NSObject {
@private
	id launchWindowController;
	id projectController;
}
- (IBAction)showAcknowledgements:(id)sender;
- (IBAction)showRegistration:(id)sender;
- (IBAction)openDocument:(id)sender;

@end
