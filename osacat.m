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
const int VERSION_MINOR = 5;
const int VERSION_BUILD = 0;


BOOL arg_verbose = NO;

ANSIEscapeHelper *ansiEscapeHelper = nil;




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


#define MAX_FLOAT_EQUALITY_ABS_ERROR 0.000001;
BOOL floatsEqual(CGFloat first, CGFloat second)
{
	return (fabs(first-second)) < MAX_FLOAT_EQUALITY_ABS_ERROR;
}


// helper struct typedef and a few functions for
// getClosestAnsiColorForColor:

typedef struct _HSB {
	CGFloat hue;
	CGFloat saturation;
	CGFloat brightness;
} HSB;

HSB makeHSB(CGFloat hue, CGFloat saturation, CGFloat brightness)
{
	HSB outHSB;
	outHSB.hue = hue;
	outHSB.saturation = saturation;
	outHSB.brightness = brightness;
	return outHSB;
}

HSB getHSBFromColor(NSColor *color)
{
	CGFloat hue = 0.0;
	CGFloat saturation = 0.0;
	CGFloat brightness = 0.0;
	[[color colorUsingColorSpaceName:NSCalibratedRGBColorSpace]
		getHue:&hue
		saturation:&saturation
		brightness:&brightness
		alpha:NULL
		];
	return makeHSB(hue, saturation, brightness);
}



// returns the closest ANSI color (from the colors used by
// ansiEscapeHelper) to the given color, or nil if the given
// color is nil.
NSColor *getClosestAnsiColorForColor(NSColor *color, BOOL foreground)
{
	if (color == nil)
		return nil;
	
	HSB givenColorHSB = getHSBFromColor(color);
	
	NSColor *closestColor = nil;
	CGFloat closestColorHueDiff = FLT_MAX;
	CGFloat closestColorSaturationDiff = FLT_MAX;
	CGFloat closestColorBrightnessDiff = FLT_MAX;
	
	// (background SGR codes are +10 from foreground ones:)
	NSUInteger sgrCodeShift = (foreground)?0:10;
	NSArray *ansiFgColorCodes = [NSArray
		arrayWithObjects:
			[NSNumber numberWithInt:SGRCodeFgBlack+sgrCodeShift],
			[NSNumber numberWithInt:SGRCodeFgRed+sgrCodeShift],
			[NSNumber numberWithInt:SGRCodeFgGreen+sgrCodeShift],
			[NSNumber numberWithInt:SGRCodeFgYellow+sgrCodeShift],
			[NSNumber numberWithInt:SGRCodeFgBlue+sgrCodeShift],
			[NSNumber numberWithInt:SGRCodeFgMagenta+sgrCodeShift],
			[NSNumber numberWithInt:SGRCodeFgCyan+sgrCodeShift],
			[NSNumber numberWithInt:SGRCodeFgWhite+sgrCodeShift],
			[NSNumber numberWithInt:SGRCodeFgBrightBlack+sgrCodeShift],
			[NSNumber numberWithInt:SGRCodeFgBrightRed+sgrCodeShift],
			[NSNumber numberWithInt:SGRCodeFgBrightGreen+sgrCodeShift],
			[NSNumber numberWithInt:SGRCodeFgBrightYellow+sgrCodeShift],
			[NSNumber numberWithInt:SGRCodeFgBrightBlue+sgrCodeShift],
			[NSNumber numberWithInt:SGRCodeFgBrightMagenta+sgrCodeShift],
			[NSNumber numberWithInt:SGRCodeFgBrightCyan+sgrCodeShift],
			[NSNumber numberWithInt:SGRCodeFgBrightWhite+sgrCodeShift],
			nil
		];
	for (NSNumber *thisSGRCodeNumber in ansiFgColorCodes)
	{
		enum sgrCode thisSGRCode = [thisSGRCodeNumber intValue];
		NSColor *thisColor = [ansiEscapeHelper colorForSGRCode:thisSGRCode];
		
		HSB thisColorHSB = getHSBFromColor(thisColor);
		
		CGFloat hueDiff = fabs(givenColorHSB.hue - thisColorHSB.hue);
		CGFloat saturationDiff = fabs(givenColorHSB.saturation - thisColorHSB.saturation);
		CGFloat brightnessDiff = fabs(givenColorHSB.brightness - thisColorHSB.brightness);
		
		// comparison depends on hue, saturation and brightness
		// (strictly in that order):
		
		if (!floatsEqual(hueDiff, closestColorHueDiff))
		{
			if (hueDiff > closestColorHueDiff)
				continue;
			closestColor = thisColor;
			closestColorHueDiff = hueDiff;
			closestColorSaturationDiff = saturationDiff;
			closestColorBrightnessDiff = brightnessDiff;
			continue;
		}
		
		if (!floatsEqual(saturationDiff, closestColorSaturationDiff))
		{
			if (saturationDiff > closestColorSaturationDiff)
				continue;
			closestColor = thisColor;
			closestColorHueDiff = hueDiff;
			closestColorSaturationDiff = saturationDiff;
			closestColorBrightnessDiff = brightnessDiff;
			continue;
		}
		
		if (!floatsEqual(brightnessDiff, closestColorBrightnessDiff))
		{
			if (brightnessDiff > closestColorBrightnessDiff)
				continue;
			closestColor = thisColor;
			closestColorHueDiff = hueDiff;
			closestColorSaturationDiff = saturationDiff;
			closestColorBrightnessDiff = brightnessDiff;
			continue;
		}
		
		// If hue (especially hue!), saturation and brightness diffs all
		// are equal to some other color, we need to prefer one or the
		// other so we'll select the more 'distinctive' color of the
		// two (this is *very* subjective, obviously). I basically just
		// looked at the hue chart, went through all the points between
		// our main ANSI colors and decided which side the middle point
		// would lean on.
		// 
		// subjective ordering of colors from most to least distinctive:
		int colorDistinctivenessOrder[6] = {
			SGRCodeFgRed+sgrCodeShift,
			SGRCodeFgMagenta+sgrCodeShift,
			SGRCodeFgBlue+sgrCodeShift,
			SGRCodeFgGreen+sgrCodeShift,
			SGRCodeFgCyan+sgrCodeShift,
			SGRCodeFgYellow+sgrCodeShift
			};
		enum sgrCode closestColorSGRCode = [ansiEscapeHelper sgrCodeForColor:closestColor isForegroundColor:foreground];
		int i;
		for (i = 0; i < 6; i++)
		{
			if (colorDistinctivenessOrder[i] == closestColorSGRCode)
				break;
			else if (colorDistinctivenessOrder[i] == thisSGRCode)
			{
				closestColor = thisColor;
				closestColorHueDiff = hueDiff;
				closestColorSaturationDiff = saturationDiff;
				closestColorBrightnessDiff = brightnessDiff;
			}
		}
	}
	
	return closestColor;
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
		HGPrintf(@"Copyright (c) 2009-2010 Ali Rantakari, http://hasseg.org/\n");
		HGPrintf(@"\n");
		exit(0);
	}
	
	
	ansiEscapeHelper = [[[ANSIEscapeHelper alloc] init] autorelease];
	
	
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
	if (!arg_ansiEscapeFormat)
	{
		HGPrint([richSource string]);
		goto donePrinting;
	}
	
	
	// change all of the colors in the attributed string
	// to colors used in ANSIEscapeHelper.
	NSMutableAttributedString *modifiedRichSource = [[[NSMutableAttributedString alloc]
		initWithAttributedString:richSource] autorelease];
	
	NSRange limitRange;
	NSRange effectiveRange;
	id attributeValue = nil;
	
	limitRange = NSMakeRange(0, [richSource length]);
	while (limitRange.length > 0)
	{
		attributeValue = [richSource
						  attribute:NSForegroundColorAttributeName
						  atIndex:limitRange.location
						  longestEffectiveRange:&effectiveRange
						  inRange:limitRange
						  ];
		if ([attributeValue isKindOfClass:[NSColor class]])
		{
			NSColor *ansiColor = getClosestAnsiColorForColor((NSColor *)attributeValue, YES);
			[modifiedRichSource addAttribute:NSForegroundColorAttributeName value:ansiColor range:effectiveRange];
		}
		
		limitRange = NSMakeRange(
			NSMaxRange(effectiveRange),
			NSMaxRange(limitRange) - NSMaxRange(effectiveRange)
			);
	}
	
	
	HGPrint([ansiEscapeHelper ansiEscapedStringWithAttributedString:modifiedRichSource]);
	
	
	
donePrinting:
	HGPrint(@"\n");
	[autoReleasePool release];
	exit(0);
}


