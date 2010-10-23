//
//  NSApplication+TLLicense.m
//  Flowrate
//
//  Created by Nathan Vander Wilt on 1/26/10.
//  Copyright 2010 Calf Trail Software, LLC. All rights reserved.
//

#import "NSApplication+TLLicense.h"

#include <openssl/rsa.h>
#include <openssl/sha.h>
#include <openssl/objects.h>


NSString* const TLLicenseApplicationRegistered = @"TLLicense_ApplicationRegistered";

static NSString* const TLLicenseKeyName = @"Name";
static NSString* const TLLicenseKeyEmail = @"Email";
static NSString* const TLLicenseKeyApp = @"Product";
static NSString* const TLLicenseKeyDate = @"Purchase";
static NSString* const TLLicenseKeyPurchase = @"Timestamp";
static NSString* const TLLicenseKeyLSig = @"Signature";


@implementation NSApplication (TLLicense)

- (void)tl_setRegistrationInfo:(NSDictionary*)theInfo {
	[[NSUserDefaults standardUserDefaults] setValue:theInfo forKey:@"TLLicense"];
	if ([self tl_registrationIsValid]) {
		[[NSNotificationCenter defaultCenter] postNotificationName:TLLicenseApplicationRegistered
															object:self];
	}
}

- (NSDictionary*)tl_registrationInfo {
	return [[NSUserDefaults standardUserDefaults] valueForKey:@"TLLicense"];
}

+ (NSData*)tl_canonicalRegistration:(NSDictionary*)registrationInfo {
	NSMutableData* canonicalData = [NSMutableData data];
	NSArray* sortedKeys = [[registrationInfo allKeys]
						   sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
	for (NSString* key in sortedKeys) {
		if ([key isEqualToString:TLLicenseKeyLSig]) continue;
		NSString* value = [registrationInfo objectForKey:key];
		const char* valueStr = [value UTF8String];
		[canonicalData appendBytes:valueStr length:strlen(valueStr)];
	}
	return canonicalData;
}

- (RSA*)tl_publicKey {
	NSAssert([NSThread isMainThread], @"Main thread only");
	NSAssert(self == NSApp, @"Singleton instance only");
	
	static RSA* pubKey = NULL;
	if (!pubKey) {
		NSData* nData = [[self delegate] tl_applicationNeedsLicensePublicKey:self];
		pubKey = RSA_new();
		pubKey->e = BN_new();
		BN_set_word(pubKey->e, 3);
		pubKey->n = BN_bin2bn([nData bytes], (int)[nData length], NULL);
	}
	return pubKey;
}

- (BOOL)tl_registrationIsValid {
	NSDictionary* registrationInfo = [self tl_registrationInfo];
	if (!registrationInfo) return NO;
	
	//NSString* bundleAppID = [[[NSBundle mainBundle] infoDictionary] objectForKey:(id)kCFBundleIdentifierKey];
	NSString* bundleAppID = @"com.calftrail.geotagalog";
	NSString* licenseAppID = [registrationInfo objectForKey:TLLicenseKeyApp];
	if (!licenseAppID || ![bundleAppID isEqual:licenseAppID]) return NO;
	
	NSData* registrationMessage = [[self class] tl_canonicalRegistration:registrationInfo];
	uint8_t registrationDigest[SHA_DIGEST_LENGTH];
	SHA1([registrationMessage bytes], [registrationMessage length], registrationDigest);
	
	RSA* pubKey = [self tl_publicKey];
	uint8_t decryptedDigest[RSA_size(pubKey)];
	NSData* encryptedDigest = [registrationInfo objectForKey:TLLicenseKeyLSig];
	int decryptedLength = RSA_public_decrypt((int)[encryptedDigest length], [encryptedDigest bytes],
											 decryptedDigest, pubKey, RSA_PKCS1_PADDING);
	if (decryptedLength != SHA_DIGEST_LENGTH) return NO;
	for (int i = 0; i < SHA_DIGEST_LENGTH; ++i) {
		if (decryptedDigest[i] != registrationDigest[i]) {
			return NO;
		}
	}
	return YES;
}

- (IBAction)tl_buyApplication:(id)sender {
	(void)sender;
	NSURL* storeURL = [NSURL URLWithString:@"http://calftrail.com/store/"];
	[[NSWorkspace sharedWorkspace] openURL:storeURL];
}

- (IBAction)tl_contactDeveloper:(id)sender {
	(void)sender;
	NSURL* contactURL = [NSURL URLWithString:@"http://calftrail.com/support.html"];
	[[NSWorkspace sharedWorkspace] openURL:contactURL];
}


@end
