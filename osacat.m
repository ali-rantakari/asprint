/*

osacat
--------------
A Small command-line program that prints out the contents of a specified
AppleScript file.

Copyright (c) 2009 Ali Rantakari (http://hasseg.org)

--------------

Licensed under the Apache License, Version 2.0 (the "License"); you may
not use this file except in compliance with the License. You may obtain
a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
License for the specific language governing permissions and limitations
under the License.

*/

#import <Cocoa/Cocoa.h>
#import <libgen.h>
#import "ANSIEscapeHelper.h"


#define DEBUG_LEVEL 3

#define DEBUG_ERROR   (DEBUG_LEVEL >= 1)
#define DEBUG_WARN    (DEBUG_LEVEL >= 2)
#define DEBUG_INFO    (DEBUG_LEVEL >= 3)
#define DEBUG_VERBOSE (DEBUG_LEVEL >= 4)

#define DDLogError(format, ...)		if(DEBUG_ERROR)   \
										NSLog((format), ##__VA_ARGS__)
#define DDLogWarn(format, ...)		if(DEBUG_WARN)    \
										NSLog((format), ##__VA_ARGS__)
#define DDLogInfo(format, ...)		if(DEBUG_INFO)    \
										NSLog((format), ##__VA_ARGS__)
#define DDLogVerbose(format, ...)	if(DEBUG_VERBOSE) \
										NSLog((format), ##__VA_ARGS__)



const int VERSION_MAJOR = 0;
const int VERSION_MINOR = 4;
const int VERSION_BUILD = 0;


BOOL arg_verbose = NO;


NSString* versionNumberStr()
{
	return [NSString stringWithFormat:@"%d.%d.%d", VERSION_MAJOR, VERSION_MINOR, VERSION_BUILD];
}



void HGPrint(NSString *aStr)
{
	[aStr writeToFile:@"/dev/stdout" atomically:NO encoding:NSUTF8StringEncoding error:NULL];
}

// other HGPrintf functions call this, and you call them
void RealHGPrintf(NSString *aStr, va_list args)
{
	NSString *str = [
		[[NSString alloc]
			initWithFormat:aStr
			locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]
			arguments:args
			] autorelease
		];
	
	[str writeToFile:@"/dev/stdout" atomically:NO encoding:NSUTF8StringEncoding error:NULL];
}

void VerboseHGPrintf(NSString *aStr, ...)
{
	if (!arg_verbose)
		return;
	va_list argList;
	va_start(argList, aStr);
	RealHGPrintf(aStr, argList);
	va_end(argList);
}

void HGPrintf(NSString *aStr, ...)
{
	va_list argList;
	va_start(argList, aStr);
	RealHGPrintf(aStr, argList);
	va_end(argList);
}

void HGPrintfErr(NSString *aStr, ...)
{
	va_list argList;
	va_start(argList, aStr);
	NSString *str = [
		[[NSString alloc]
			initWithFormat:aStr
			locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]
			arguments:argList
			] autorelease
		];
	va_end(argList);
	
	[str writeToFile:@"/dev/stderr" atomically:NO encoding:NSUTF8StringEncoding error:NULL];
}







int main(int argc, char *argv[])
{
	NSAutoreleasePool *autoReleasePool = [[NSAutoreleasePool alloc] init];
	
	char *myBasename = basename(argv[0]);
	if (argc == 1)
	{
		HGPrintf(@"usage: %s [options] <file>\n", myBasename);
		HGPrintf(@"\n");
		HGPrintf(@"  Prints out the contents of an AppleScript\n");
		HGPrintf(@"  file.\n");
		HGPrintf(@"\n");
		HGPrintf(@" options:\n");
		HGPrintf(@"\n");
		HGPrintf(@"  -f  Don't use ANSI escape sequences for\n");
		HGPrintf(@"      formatting the output.\n");
		HGPrintf(@"\n");
		HGPrintf(@"Version %@\n", versionNumberStr());
		HGPrintf(@"Copyright (c) 2009 Ali Rantakari, http://hasseg.org/\n");
		HGPrintf(@"\n");
		exit(0);
	}
	
	
	NSString *providedPath = [[NSString stringWithUTF8String:argv[argc-1]] stringByStandardizingPath];
	
	
	BOOL arg_ansiEscapeFormat = YES;
	
	if (argc > 2)
	{
		int i;
		for (i = 0; i < argc; i++)
		{
			if (strcmp(argv[i], "-f") == 0)
				arg_ansiEscapeFormat = NO;
		}
	}
	
	
	if (![[NSFileManager defaultManager] fileExistsAtPath:providedPath])
	{
		HGPrintfErr(@"Error: provided path does not exist:\n%s\n\n", [providedPath UTF8String]);
		exit(1);
	}
	if (![[providedPath pathExtension] isEqualToString:@"scpt"])
	{
		HGPrintfErr(@"Error: specified filename does not have extension: .scpt\n\n");
		exit(1);
	}
	
	
	NSURL *fileURL = [NSURL fileURLWithPath:providedPath];
	NSDictionary *initErrorInfo = nil;
	NSAppleScript *as = [[[NSAppleScript alloc] initWithContentsOfURL:fileURL error:&initErrorInfo] autorelease];
	if (as == nil)
	{
		HGPrintfErr(@"Error loading file: %@", initErrorInfo);
		exit(1);
	}
	
	// print out the contents
	
	NSAttributedString *richSource = [as richTextSource];
	if (arg_ansiEscapeFormat)
	{
		ANSIEscapeHelper *ansiHelper = [[[ANSIEscapeHelper alloc] init] autorelease];
		HGPrint([ansiHelper ansiEscapedStringWithAttributedString:richSource]);
	}
	else
	{
		HGPrint([richSource string]);
	}
	
	HGPrint(@"\n");
	
	[autoReleasePool release];
	exit(0);
}


