//
//  DuxJavaScriptBaseElement.m
//  Dux
//
//  Created by Abhi Beckert on 2011-11-25.
//  
//  This is free and unencumbered software released into the public domain.
//  For more information, please refer to <http://unlicense.org/>
//

#import "DuxJavaScriptBaseElement.h"
#import "DuxJavaScriptLanguage.h"

@implementation DuxJavaScriptBaseElement

static NSCharacterSet *nextElementCharacterSet;
static NSCharacterSet *numericCharacterSet;
static NSCharacterSet *nonNumericCharacterSet;
static NSCharacterSet *alphabeticCharacterSet;

static DuxJavaScriptSingleQuotedStringElement *singleQuotedStringElement;
static DuxJavaScriptDoubleQuotedStringElement *doubleQuotedStringElement;
static DuxJavaScriptNumberElement *numberElement;
static DuxJavaScriptKeywordElement *keywordElement;
static DuxJavaScriptSingleLineCommentElement *singleLineCommentElement;
static DuxJavaScriptBlockCommentElement *blockCommentElement;
static DuxJavaScriptRegexElement *regexElement;

+ (void)initialize
{
  [super initialize];
  
  nextElementCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"'\"/0123456789"];
  numericCharacterSet = [NSCharacterSet decimalDigitCharacterSet];
  nonNumericCharacterSet = [numericCharacterSet invertedSet];
  alphabeticCharacterSet = [NSCharacterSet letterCharacterSet];
  
  singleQuotedStringElement = [DuxJavaScriptSingleQuotedStringElement sharedInstance];
  doubleQuotedStringElement = [DuxJavaScriptDoubleQuotedStringElement sharedInstance];
  numberElement = [DuxJavaScriptNumberElement sharedInstance];
  keywordElement = [DuxJavaScriptKeywordElement sharedInstance];
  singleLineCommentElement = [DuxJavaScriptSingleLineCommentElement sharedInstance];
  blockCommentElement = [DuxJavaScriptBlockCommentElement sharedInstance];
  regexElement = [DuxJavaScriptRegexElement sharedInstance];
}

- (id)init
{
  return [self initWithLanguage:[DuxJavaScriptLanguage sharedInstance]];
}

- (NSUInteger)lengthInString:(NSAttributedString *)string startingAt:(NSUInteger)startingAt nextElement:(DuxLanguageElement *__strong*)nextElement
{
  // scan up to the next character
  BOOL keepLooking = YES;
  NSUInteger searchStartLocation = startingAt;
  NSRange foundCharacterSetRange;
  unichar characterFound;
  BOOL foundSingleLineComment = NO;
  BOOL foundRegexPattern = NO;
  while (keepLooking) {
    foundCharacterSetRange = [string.string rangeOfCharacterFromSet:nextElementCharacterSet options:NSLiteralSearch range:NSMakeRange(searchStartLocation, string.string.length - searchStartLocation)];
    
    if (foundCharacterSetRange.location == NSNotFound)
      break;
    
    // did we find a / character? check if it's a comment or a regex pattern
    characterFound = [string.string characterAtIndex:foundCharacterSetRange.location];
    if (characterFound == '/') {
      if (string.string.length > (foundCharacterSetRange.location + 1)) {
        characterFound = [string.string characterAtIndex:foundCharacterSetRange.location + 1];
        if (characterFound == '/') {
          foundSingleLineComment = YES;
          foundRegexPattern = NO;
        } else if (characterFound == '*') {
          foundSingleLineComment = NO;
          foundRegexPattern = NO;
        } else if ([[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:characterFound]) { // whitespace, not a regex pattern
          foundSingleLineComment = NO;
          foundRegexPattern = NO;
          keepLooking = YES;
          searchStartLocation += 1;
          continue;
        } else { // regex pattern
          foundSingleLineComment = NO;
          foundRegexPattern = YES;
          characterFound = '/';
        }
      } else { // regex pattern
        foundSingleLineComment = NO;
        foundRegexPattern = YES;
        characterFound = '/';
      }
    }
    
    // did we find a number? make sure it is wrapped in non-alpha characters
    else if ([numericCharacterSet characterIsMember:characterFound]) {
      BOOL prevCharIsAlphabetic;
      if (foundCharacterSetRange.location == 0) {
        prevCharIsAlphabetic = NO;
      } else {
        prevCharIsAlphabetic = [alphabeticCharacterSet characterIsMember:[string.string characterAtIndex:foundCharacterSetRange.location - 1]];
      }
      
      NSUInteger nextNonNumericCharacterLocation = [string.string rangeOfCharacterFromSet:nonNumericCharacterSet options:NSLiteralSearch range:NSMakeRange(foundCharacterSetRange.location, string.string.length - foundCharacterSetRange.location)].location;
      BOOL nextCharIsAlphabetic;
      if (nextNonNumericCharacterLocation == NSNotFound || [string.string characterAtIndex:nextNonNumericCharacterLocation] == 'x') {
        nextNonNumericCharacterLocation = string.string.length;
        nextCharIsAlphabetic = NO;
      } else {
        nextCharIsAlphabetic = [alphabeticCharacterSet characterIsMember:[string.string characterAtIndex:nextNonNumericCharacterLocation]];
      }
      
      if (prevCharIsAlphabetic || nextCharIsAlphabetic) {
        searchStartLocation = nextNonNumericCharacterLocation;
        keepLooking = YES;
        continue;
      }
    }
    
    keepLooking = NO;
  }
  
  // search for the next keyword
  BOOL needKeywordSearch = NO;
  id keywordString = string;
  if ([keywordString isKindOfClass:[NSAttributedString class]])
    keywordString = [keywordString string];
  if (keywordString != [DuxJavaScriptLanguage keywordIndexString])
    needKeywordSearch = YES;
  if (!NSLocationInRange(startingAt, [DuxJavaScriptLanguage keywordIndexRange]))
    needKeywordSearch = YES;
  if (foundCharacterSetRange.location != NSNotFound && !NSLocationInRange(foundCharacterSetRange.location, [DuxJavaScriptLanguage keywordIndexRange]))
    needKeywordSearch = YES;
  if (foundCharacterSetRange.location == NSNotFound && !NSLocationInRange(string.length - 1, [DuxJavaScriptLanguage keywordIndexRange]))
    needKeywordSearch = YES;
  if (needKeywordSearch) {
    [[DuxJavaScriptLanguage sharedInstance] findKeywordsInString:keywordString inRange:NSMakeRange(startingAt, MIN(string.length, startingAt + 10000) - startingAt)];
  }
  
  NSRange foundKeywordRange = NSMakeRange(NSNotFound, 0);
  NSIndexSet *keywordIndexes = [DuxJavaScriptLanguage keywordIndexSet];
  if (keywordIndexes) {
    NSUInteger foundKeywordMax = (foundCharacterSetRange.location == NSNotFound) ? string.string.length : foundCharacterSetRange.location;
    for (NSUInteger index = startingAt; index < foundKeywordMax; index++) {
      if ([keywordIndexes containsIndex:index]) {
        if (foundKeywordRange.location == NSNotFound) {
          foundKeywordRange.location = index;
          foundKeywordRange.length = 1;
        } else {
          foundKeywordRange.length++;
        }
      } else {
        if (foundKeywordRange.location != NSNotFound) {
          break;
        }
      }
    }
  }
  
  // scanned up to the end of the string?
  if (foundCharacterSetRange.location == NSNotFound && foundKeywordRange.location == NSNotFound)
    return string.string.length - startingAt;
  
  // did we find a keyword before a character?
  if (foundKeywordRange.location != NSNotFound) {
    if (foundCharacterSetRange.location == NSNotFound || foundKeywordRange.location < foundCharacterSetRange.location) {
      *nextElement = keywordElement;
      return foundKeywordRange.location - startingAt;
    }
  }
  
  // what character did we find?
  switch (characterFound) {
    case '\'':
      *nextElement = singleQuotedStringElement;
      return foundCharacterSetRange.location - startingAt;
    case '"':
      *nextElement = doubleQuotedStringElement;
      return foundCharacterSetRange.location - startingAt;
    case '0':
    case '1':
    case '2':
    case '3':
    case '4':
    case '5':
    case '6':
    case '7':
    case '8':
    case '9':
      *nextElement = numberElement;
      return foundCharacterSetRange.location - startingAt;
    case '/':
      if (foundSingleLineComment) {
        *nextElement = singleLineCommentElement;
        return foundCharacterSetRange.location - startingAt;
      } else if (foundRegexPattern) {
        *nextElement = regexElement;
        return foundCharacterSetRange.location - startingAt;
      }
    case '*':
      *nextElement = blockCommentElement;
      return foundCharacterSetRange.location - startingAt;
  }
  
  // should never reach this, but add this line anyway to make the compiler happy
  return string.string.length - startingAt;
}

@end
