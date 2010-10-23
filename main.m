//
//  main.m
//  Tagalog
//
//  Created by Nathan Vander Wilt on 1/19/09.
//  Copyright __MyCompanyName__ 2009. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <TLCrashReporter/TLCrashReporter.h>
#import "TLJimBos.h"

int main(int argc, char *argv[])
{
	/* NOTE: this is currently necessary to ensure license URLs clicked
	 when app isn't running are still handled. */
	(void)[TLJimBos sharedRegistrar];
	
	TLCrashReporterRegisterSignals();
    return NSApplicationMain(argc,  (const char **) argv);
}
