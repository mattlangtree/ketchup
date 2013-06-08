//
//  DuxPHPDoubleQuoteStringElement.m
//  Dux
//
//  Created by Abhi Beckert on 2011-11-16.
//  
//  This is free and unencumbered software released into the public domain.
//  For more information, please refer to <http://unlicense.org/>
//

#import "DuxPHPDoubleQuoteStringElement.h"
#import "DuxPHPLanguage.h"

@implementation DuxPHPDoubleQuoteStringElement

static NSCharacterSet *nextElementCharacterSet;
static NSCharacterSet *validVariableCharacterSet;
static DuxPHPVariableElement *variableElement;
static NSColor *color;

+ (void)initialize
{
  [super initialize];
  
  nextElementCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"\"\\$"];
  validVariableCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwrxyzABCDEFGHIJKLMNOPQRSTUVWRXYZ_"];
  
  variableElement = [DuxPHPVariableElement sharedInstance];
  
  color = [NSColor colorWithCalibratedRed:0.76 green:0.1 blue:0.08 alpha:1];
}

- (id)init
{
  return [self initWithLanguage:[DuxPHPLanguage sharedInstance]];
}

- (NSUInteger)lengthInString:(NSAttributedString *)string startingAt:(NSUInteger)startingAt nextElement:(DuxLanguageElement *__strong*)nextElement
{
  BOOL keepLooking = YES;
  NSUInteger searchStartLocation = startingAt;
  NSRange foundRange;
  unichar characterFound;
  while (keepLooking) {
    // find next character
    foundRange = [string.string rangeOfCharacterFromSet:nextElementCharacterSet options:NSLiteralSearch range:NSMakeRange(searchStartLocation, string.string.length - searchStartLocation)];
    
    // not found, or the last character in the string?
    if (foundRange.location == NSNotFound || foundRange.location == (string.string.length - 1))
      return string.string.length - startingAt;
    
    // because the start/end characters are the same, so we need to make sure we didn't just find the first character
    if (foundRange.location == startingAt) {
      // are the attirbutes for the *previous* character a child of us? in this situation we have actually found the closing quote of "foo $bar"
      NSArray *previousCharElements = [string attribute:@"DuxLanguageElementStack" atIndex:foundRange.location - 2 effectiveRange:NULL];
      if (!previousCharElements || previousCharElements.count < 2 || [previousCharElements objectAtIndex:previousCharElements.count-2] != self) {
        searchStartLocation++;
        continue;
      }
    }
    
    // backslash? keep searching
    characterFound = [string.string characterAtIndex:foundRange.location];
    if (characterFound == '\\') {
      searchStartLocation = foundRange.location + 2;
      continue;
    }
    
    // variable? make sure next char is alphanumeric
    if (characterFound == '$' && string.string.length > foundRange.location + 1 && ![validVariableCharacterSet characterIsMember:[string.string characterAtIndex:foundRange.location + 1]]) {
      searchStartLocation = foundRange.location + 1;
      continue;
    }
    
    // stop looking
    keepLooking = NO;
  }
  
  // what's next?
  switch (characterFound) {
    case '"':
      return (foundRange.location + 1) - startingAt;
    case '$':
      *nextElement = variableElement;
      return foundRange.location - startingAt;
  }

  
  // should never reach this, but add this line anyway to make the compiler happy
  return string.string.length - startingAt;
}

- (NSColor *)color
{
  return color;
}

@end
