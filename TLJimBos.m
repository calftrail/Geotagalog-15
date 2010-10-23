//
//  TLJimBos.m
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 1/20/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "TLJimBos.h"

#import "NSApplication+TLLicense.h"
#import <CommonCrypto/CommonDigest.h>

const NSUInteger TLJimBos_MaximumUseCount = 10;
static NSString* const TLJimBos_StorePage = @"http://calftrail.com/store";
static NSString* const TLJimBos_ContactAddress = @"support@calftrail.com";
static NSString* const TLJimBos_ContactSubject = @"Geotagalog feedback";
static NSString* const TLJimBos_ContactBody = @"";

static NSString* const TLJimBos_UserNameKey = @"com.calftrail.mercatalog.username";
static NSString* const TLJimBos_ProductKey = @"com.calftrail.mercatalog.productkey";

NSString* const TLJimBosAppRegisteredNotification = @"TLJimBosAppRegistered";


@interface TLJimBos ()
- (BOOL)isRegistered;
- (BOOL)checkKey:(NSString*)licenseKey;
- (NSString*)emailAddressFromKey:(NSString*)licenseKey;
@end


@implementation TLJimBos

+ (id)sharedRegistrar {
	static TLJimBos* sharedRegistrar = nil;
	if (!sharedRegistrar) {
		sharedRegistrar = [TLJimBos new];
		// http://www.cocoabuilder.com/archive/message/cocoa/2008/8/10/215295
		[[NSAppleEventManager sharedAppleEventManager] setEventHandler:sharedRegistrar
														   andSelector:@selector(handleURLEvent:reply:)
														 forEventClass:kInternetEventClass
															andEventID:kAEGetURL];
		[[NSNotificationCenter defaultCenter] addObserver:sharedRegistrar selector:@selector(registeredNew:)
													 name:TLLicenseApplicationRegistered object:nil];
	}
	return sharedRegistrar;
}

- (void)dealloc {
	[registrationWindow release];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[[NSAppleEventManager sharedAppleEventManager] removeEventHandlerForEventClass:kInternetEventClass andEventID:kAEGetURL];
	[super dealloc];
}

- (void)handleURLEvent:(NSAppleEventDescriptor *)event reply:(NSAppleEventDescriptor *)replyEvent {
	(void)replyEvent;
	
	NSString* urlString = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
	NSURL* url = [NSURL URLWithString:urlString];
	//NSLog(@"Received URL: %@\n", url);
	
	if (![[url scheme] isEqualToString:@"x-com-calftrail-license-tagalog"]) {
		return;
	}
	
	NSString* licenseKey = [[url resourceSpecifier] stringByReplacingOccurrencesOfString:@"//" withString:@""];
	NSString* userName = NSFullUserName();
	
	BOOL registered = [self registerApplication:licenseKey user:userName];
	if (registered && registrationWindow) {
		[self closeRegistrationWindow:self];
	}
	
	if (registered) {
		[self showRegistrationWindow:self];
	}
	else {
		NSAlert* registrationError = [[NSAlert new] autorelease];
		[registrationError setAlertStyle:NSWarningAlertStyle];
		[registrationError setMessageText:@"Automatic registration failed!"];
		[registrationError setInformativeText:
		 @"Geotagalog could not be registered through the link you just clicked. "
		 @"You can try registering using the manual window, or contact us if you are having trouble. "
		 @"Sorry for the inconvenience."];
		(void)[registrationError addButtonWithTitle:@"OK"];
		NSButton* contact = [registrationError addButtonWithTitle:@"Contact Calf Trail"];
		[contact setBezelStyle:NSRoundRectBezelStyle];
		
		NSInteger button = [registrationError runModal];
		if (button == NSAlertSecondButtonReturn) {
			[self contactCalfTrail:self];
		}
		else {
			[self showRegistrationWindow:self];
		}
	}
}

- (IBAction)contactCalfTrail:(id)sender {
	(void)sender;
	//http://www.ietf.org/rfc/rfc2368
	NSString* mailString = [NSString stringWithFormat:@"mailto:%@?subject=%@&body=%@",
							TLJimBos_ContactAddress, TLJimBos_ContactSubject, TLJimBos_ContactBody];
	NSString* encodedMailString = [mailString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	NSURL* mailURL = [NSURL URLWithString:encodedMailString];
	[[NSWorkspace sharedWorkspace] openURL:mailURL];
}

- (IBAction)buyMercatalog:(id)sender {
	(void)sender;
	NSURL* storeURL = [NSURL URLWithString:TLJimBos_StorePage];
	[[NSWorkspace sharedWorkspace] openURL:storeURL];
}

- (BOOL)continueExportDemoPrompt {
	NSAssert(![self isRegistered], @"Don't demo prompt when already registered!");
	
	NSAlert* demoInfo = [[NSAlert new] autorelease];
	[demoInfo setAlertStyle:NSWarningAlertStyle];
	[demoInfo setMessageText:@"Thanks for trying Geotagalog!"];
	NSString* info = [NSString stringWithString:
					  @"You are using a demo version of Geotagalog, which limits the amount of photos you may export. "
					  @"To remove this limitation, you will need to purchase a registration code."];
	[demoInfo setInformativeText:info];
	
	(void)[demoInfo addButtonWithTitle:@"Export 24 photos"];
	NSButton* buy = [demoInfo addButtonWithTitle:@"Purchase"];
	[buy setBezelStyle:NSRoundRectBezelStyle];
	NSButton* contact = [demoInfo addButtonWithTitle:@"Contact Calf Trail"];
	[contact setBezelStyle:NSRoundRectBezelStyle];
	
	NSInteger button = [demoInfo runModal];
	if (button == NSAlertFirstButtonReturn) {
		// use demo
		return YES;
	}
	else if (button == NSAlertSecondButtonReturn) {
		[self buyMercatalog:self];
	}
	else if (button == NSAlertThirdButtonReturn) {
		[self contactCalfTrail:self];
	}
	return NO;
}

- (IBAction)showRegistrationWindow:(id)sender {
	(void)sender;
	NSString* userName = [[NSUserDefaults standardUserDefaults] objectForKey:TLJimBos_UserNameKey];
	if ([self isRegistered]) {
		[NSBundle loadNibNamed:@"ThankYou" owner:self];
		[nameField setStringValue:userName];
		
		NSString* licenseKey = [[NSUserDefaults standardUserDefaults] objectForKey:TLJimBos_ProductKey];
		NSString* emailAddress = [self emailAddressFromKey:licenseKey];
		[emailField setStringValue:emailAddress];
	}
	else {
		[NSBundle loadNibNamed:@"Registration" owner:self];
		if (!userName) {
			userName = NSFullUserName();
		}
		[nameField setStringValue:userName];
	}
	[registrationWindow makeKeyAndOrderFront:self];
}

- (IBAction)registerByForm:(id)sender {
	(void)sender;
	
	NSString* licenseKey = [registrationCode stringValue];
	NSString* userName = [nameField stringValue];
	BOOL registered = [self registerApplication:licenseKey user:userName];
	if (!registered) {
		NSBeep();
		[registerButton setEnabled:NO];
	}
	else {
		[self closeRegistrationWindow:self];
		[self showRegistrationWindow:self];
	}
}

- (void)controlTextDidChange:(NSNotification*)changeNotification {
	if ([changeNotification object] != registrationCode) return;
	
	NSString* licenseKey = [registrationCode stringValue];
	if ([self checkKey:licenseKey]) {
		[registerButton setEnabled:YES];
	}
	else {
		[registerButton setEnabled:NO];
	}
}

- (void)cleanupWindow {
	registrationWindow = nil;
	nameField = nil;
	emailField = nil;
	registrationCode = nil;
	registerButton = nil;
}

- (void)windowWillClose:(NSNotification *)notification {
	(void)notification;
	[self cleanupWindow];
}

- (IBAction)closeRegistrationWindow:(id)sender {
	(void)sender;
	[registrationWindow close];
}

- (NSString*)createLicenseKeyWithEmail:(NSString*)email productCode:(NSString*)productCode secret:(NSString*)secret {
	NSString* stringToHash = [NSString stringWithFormat:@"%@%@%@", email, productCode, secret];
	
	const char* cStringToHash = [stringToHash UTF8String];
	unsigned char hash[CC_SHA1_DIGEST_LENGTH];
	CC_SHA1(cStringToHash, (CC_LONG)strlen(cStringToHash), hash);
	
	NSString* hashString = [NSString stringWithFormat:
							@"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
							hash[0], hash[1], hash[2], hash[3],
							hash[4], hash[5], hash[6], hash[7],
							hash[8], hash[9], hash[10], hash[11],
							hash[12], hash[13], hash[14], hash[15],
							hash[16], hash[17], hash[18], hash[19], hash[20] ];
	return [NSString stringWithFormat:@"%@%@%@",
			email,
			@"@@",
			hashString];
}

- (NSString*)emailAddressFromKey:(NSString*)licenseKey {
	NSArray* sections = [licenseKey componentsSeparatedByString:@"@@"];
	NSString* emailAddress = nil;
	if ([sections count]) {
		emailAddress = [sections objectAtIndex:0];
	}
	return emailAddress;
}

- (BOOL)licenseKeyIsValid:(NSString*)licenseKey productCode:(NSString*)productCode secret:(NSString*)secret {
	BOOL result = NO;
	NSString* emailAddress = [self emailAddressFromKey:licenseKey];
	if (emailAddress) {
		NSString* generatedLicense = [self createLicenseKeyWithEmail:emailAddress
														 productCode:productCode
															  secret:secret];
		if ([generatedLicense isEqualToString:licenseKey]) {
			result = YES;
		}
	}
	return result;
}

- (BOOL)checkKey:(NSString*)licenseKey {
	if (!licenseKey) return NO;
	
	static NSString* const productCode = @"tagalog-1.0";
	static NSString* const secret = @"pleasesupportourworkandfamilies";
	NSString* extraSecret = [NSString stringWithFormat:@"%c%c%c%s%c", 'C', 'T', 'S', "llc", '1'];
	NSString* fullSecret = [secret stringByAppendingString:extraSecret];
	return [self licenseKeyIsValid:licenseKey productCode:productCode secret:fullSecret];
}

- (BOOL)isRegistered {
	NSString* licenseKey = [[NSUserDefaults standardUserDefaults] objectForKey:TLJimBos_ProductKey];
	BOOL oldKey = [self checkKey:licenseKey];
	return oldKey || [NSApp tl_registrationIsValid];
}

- (BOOL)registerApplication:(NSString*)licenseKey
					   user:(NSString*)userName
{
	[[NSUserDefaults standardUserDefaults] setObject:userName forKey:TLJimBos_UserNameKey];
	[[NSUserDefaults standardUserDefaults] setObject:licenseKey forKey:TLJimBos_ProductKey];
	BOOL saved = [[NSUserDefaults standardUserDefaults] synchronize];
	if (!saved) {
		NSLog(@"Could not save user defaults O_o");
		return NO;
	}
	
	BOOL valid = [self isRegistered];
	if (!valid) {
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:TLJimBos_ProductKey];
	}
	else {
		[[NSNotificationCenter defaultCenter] postNotificationName:TLJimBosAppRegisteredNotification object:self];
	}
	return valid;
}

- (void)registeredNew:(NSNotification*)aNotification {
	(void)aNotification;
	[[NSNotificationCenter defaultCenter] postNotificationName:TLJimBosAppRegisteredNotification object:self];
}

@end
