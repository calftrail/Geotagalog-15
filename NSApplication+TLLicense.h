//
//  NSApplication+TLLicense.h
//  Flowrate
//
//  Created by Nathan Vander Wilt on 1/26/10.
//  Copyright 2010 Calf Trail Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSApplication (TLLicense)

- (void)tl_setRegistrationInfo:(NSDictionary*)theInfo;
- (NSDictionary*)tl_registrationInfo;
- (BOOL)tl_registrationIsValid;

- (IBAction)tl_buyApplication:(id)sender;
- (IBAction)tl_contactDeveloper:(id)sender;

@end


@interface NSObject (TLLicenseDelegate)
- (NSData*)tl_applicationNeedsLicensePublicKey:(NSApplication*)sender;
@end

extern NSString* const TLLicenseApplicationRegistered;
