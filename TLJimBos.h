//
//  TLJimBos.h
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 1/20/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

extern NSString* const TLJimBosAppRegisteredNotification;

@interface TLJimBos : NSObject {
	IBOutlet NSWindow* registrationWindow;
	__weak IBOutlet NSTextField* nameField;
	__weak IBOutlet NSTextField* emailField;
	__weak IBOutlet NSTextField* registrationCode;
	__weak IBOutlet NSButton* registerButton;
@private
}

+ (id)sharedRegistrar;


- (BOOL)isRegistered;

- (BOOL)continueExportDemoPrompt;
- (IBAction)showRegistrationWindow:(id)sender;

- (IBAction)closeRegistrationWindow:(id)sender;
- (IBAction)buyMercatalog:(id)sender;
- (IBAction)contactCalfTrail:(id)sender;
- (IBAction)registerByForm:(id)sender;

- (BOOL)registerApplication:(NSString*)licenseKey
					   user:(NSString*)userName;

@end
