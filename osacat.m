/*

osacat
--------------
A Small command-line program that prints out the contents of a specified
AppleScript file.

Copyright (c) 2009-2010 Ali Rantakari (http://hasseg.org)

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

#define MUTABLE_ATTR_STR(x)				[[[NSMutableAttributedString alloc] initWithString:(x)] autorelease]
#define ATTR_STR(x)						[[[NSAttributedString alloc] initWithString:(x)] autorelease]
#define WHITESPACE(x)					[@"" stringByPaddingToLength:(x) withString:@" " startingAtIndex:0]


const int VERSION_MAJOR = 0;
const int VERSION_MINOR = 5;
const int VERSION_BUILD = 0;


BOOL arg_verbose = NO;
ANSIEscapeHelper *ansiEscapeHelper = nil;


NSString* versionNumberStr()
{
	return [NSString stringWithFormat:@"%d.%d.%d", VERSION_MAJOR, VERSION_MINOR, VERSION_BUILD];
}

void Print(NSString *aStr)
{
	[aStr writeToFile:@"/dev/stdout" atomically:NO encoding:NSUTF8StringEncoding error:NULL];
}

// other Printf functions call this, and you call them
void RealPrintf(NSString *aStr, va_list args)
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

void VerbosePrintf(NSString *aStr, ...)
{
	if (!arg_verbose)
		return;
	va_list argList;
	va_start(argList, aStr);
	RealPrintf(aStr, argList);
	va_end(argList);
}

void Printf(NSString *aStr, ...)
{
	va_list argList;
	va_start(argList, aStr);
	RealPrintf(aStr, argList);
	va_end(argList);
}

void PrintfErr(NSString *aStr, ...)
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


// replaces all occurrences of searchStr in str with replaceStr
void replaceInMutableAttrStr(NSMutableAttributedString *str, NSString *searchStr, NSAttributedString *replaceStr)
{
	if (str == nil || searchStr == nil || replaceStr == nil)
		return;
	
	NSUInteger replaceStrLength = [replaceStr length];
	NSString *strRegularString = [str string];
	NSRange searchRange = NSMakeRange(0, [strRegularString length]);
	NSRange foundRange;
	do
	{
		foundRange = [strRegularString rangeOfString:searchStr options:NSLiteralSearch range:searchRange];
		if (foundRange.location != NSNotFound)
		{
			[str replaceCharactersInRange:foundRange withAttributedString:replaceStr];
			
			strRegularString = [str string];
			searchRange.location = foundRange.location + replaceStrLength;
			searchRange.length = [strRegularString length] - searchRange.location;
		}
	}
	while (foundRange.location != NSNotFound);
}



int main(int argc, char *argv[])
{
	NSAutoreleasePool *autoReleasePool = [[NSAutoreleasePool alloc] init];
	
	char *myBasename = basename(argv[0]);
	if (argc == 1)
	{
		Printf(@"usage: %s [options] <file>\n", myBasename);
		Printf(@"\n");
		Printf(@"  Prints out the contents of an AppleScript file.\n");
		Printf(@"\n");
		Printf(@" options:\n");
		Printf(@"\n");
		Printf(@"  -f  Don't use ANSI escape sequences for\n");
		Printf(@"      formatting the output.\n");
		Printf(@"  -t  Don't replace tabs with spaces.\n");
		Printf(@"  -tl <NUM>\n");
		Printf(@"      Use <NUM> spaces to replace a tab.\n");
		Printf(@"\n");
		Printf(@"Version %@\n", versionNumberStr());
		Printf(@"Copyright (c) 2009-2010 Ali Rantakari, http://hasseg.org/\n");
		Printf(@"\n");
		exit(0);
	}
	
	
	ansiEscapeHelper = [[[ANSIEscapeHelper alloc] init] autorelease];
	
	NSString *providedPath = [[NSString stringWithUTF8String:argv[argc-1]] stringByStandardizingPath];
	
	BOOL arg_ansiEscapeFormat = YES;
	BOOL arg_tabsToSpaces = YES;
	NSUInteger arg_tabLength = 4;
	
	if (argc > 2)
	{
		int i;
		for (i = 0; i < argc; i++)
		{
			if (strcmp(argv[i], "-f") == 0)
				arg_ansiEscapeFormat = NO;
			else if (strcmp(argv[i], "-t") == 0)
				arg_tabsToSpaces = NO;
			else if ((strcmp(argv[i], "-tl") == 0) && (i+1 < argc))
				arg_tabLength = abs([[NSString stringWithCString:argv[i+1] encoding:NSUTF8StringEncoding] integerValue]);
		}
	}
	
	if (![[NSFileManager defaultManager] fileExistsAtPath:providedPath])
	{
		PrintfErr(@"Error: provided path does not exist:\n%s\n\n", [providedPath UTF8String]);
		exit(1);
	}
	
	// read in the script file
	NSURL *fileURL = [NSURL fileURLWithPath:providedPath];
	NSDictionary *initErrorInfo = nil;
	NSAppleScript *as = [[[NSAppleScript alloc] initWithContentsOfURL:fileURL error:&initErrorInfo] autorelease];
	if (as == nil)
	{
		PrintfErr(@"Error loading file: %@", initErrorInfo);
		exit(1);
	}
	
	NSMutableAttributedString *richSource = [[[NSMutableAttributedString alloc] initWithAttributedString:[as richTextSource]] autorelease];
	
	if (arg_tabsToSpaces)
		replaceInMutableAttrStr(richSource, @"\t", ATTR_STR(WHITESPACE(arg_tabLength)));
	
	// print out the contents
	if (arg_ansiEscapeFormat)
		Print([ansiEscapeHelper ansiEscapedStringWithAttributedString:richSource]);
	else
		Print([richSource string]);
	
	Print(@"\n");
	
	[autoReleasePool release];
	exit(0);
}


