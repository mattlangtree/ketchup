//
//  DuxJavaScriptLanguage.m
//  Dux
//
//  Created by Abhi Beckert on 2011-11-25.
//  
//  This is free and unencumbered software released into the public domain.
//  For more information, please refer to <http://unlicense.org/>
//

#import "DuxJavaScriptLanguage.h"

static NSRegularExpression *keywordsExpression;
static NSIndexSet *keywordIndexSet = nil;
static NSRange keywordIndexRange = {NSNotFound, 0};
static __weak id keywordIndexString = nil;

@implementation DuxJavaScriptLanguage

+ (void)load
{
  [DuxLanguage registerLanguage:[self class]];
}

- (DuxLanguageElement *)baseElement
{
  return [DuxJavaScriptBaseElement sharedInstance];
}

- (void)wrapCommentsAroundRange:(NSRange)commentRange ofTextView:(NSTextView *)textView
{
  NSString *existingString = [textView.textStorage.string substringWithRange:commentRange];
  
  NSString *commentedString= [NSString stringWithFormat:@"// %@", existingString];
  commentedString = [commentedString stringByReplacingOccurrencesOfString:@"(\n)" withString:@"$1// " options:NSRegularExpressionSearch range:NSMakeRange(0, commentedString.length)];
  
  [textView insertText:commentedString replacementRange:commentRange];
  [textView setSelectedRange:NSMakeRange(commentRange.location, commentedString.length)];
}

- (void)removeCommentsAroundRange:(NSRange)commentRange ofTextView:(NSTextView *)textView
{
  NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:@"^\\s*// ?" options:NSRegularExpressionAnchorsMatchLines error:NULL];
  
  NSMutableString *newString = [[textView.textStorage.string substringWithRange:commentRange] mutableCopy];
  [expression replaceMatchesInString:newString options:0 range:NSMakeRange(0, newString.length) withTemplate:@""];
  
  [textView insertText:[newString copy] replacementRange:commentRange];
  [textView setSelectedRange:NSMakeRange(commentRange.location, newString.length)];
}

+ (NSIndexSet *)keywordIndexSet
{
  return keywordIndexSet;
}

+ (NSRange)keywordIndexRange
{
  return keywordIndexRange;
}

+ (id)keywordIndexString
{
  return keywordIndexString;
}

- (void)prepareToParseTextStorage:(NSTextStorage *)textStorage inRange:(NSRange)range
{
  [super prepareToParseTextStorage:textStorage inRange:range];
  
  [self findKeywordsInString:textStorage.string inRange:range];
}

- (void)findKeywordsInString:(NSString *)string inRange:(NSRange)range
{
  if (!keywordsExpression) {
    NSArray *keywords = [[NSArray alloc] initWithObjects:@"\\$", @"break", @"case", @"catch", @"continue", @"debugger", @"default", @"delete", @"do", @"else", @"false", @"finally", @"for", @"function", @"if", @"in", @"instanceof", @"new", @"return", @"switch", @"this", @"throw", @"true", @"try", @"typeof", @"var", @"void", @"while", @"with", nil];
    
    keywordsExpression = [[NSRegularExpression alloc] initWithPattern:[[NSString alloc] initWithFormat:@"\\b(%@)\\b", [keywords componentsJoinedByString:@"|"]] options:NSRegularExpressionCaseInsensitive error:NULL];
  }
  
  NSMutableIndexSet *keywordIndexesMutable = [[NSIndexSet indexSet] mutableCopy];
  [keywordsExpression enumerateMatchesInString:string options:0 range:range usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop){
    [keywordIndexesMutable addIndexesInRange:match.range];
  }];
  
  keywordIndexSet = [keywordIndexesMutable copy];
  keywordIndexRange = range;
  keywordIndexString = string;
}

+ (BOOL)isDefaultLanguageForURL:(NSURL *)URL textContents:(NSString *)textContents
{
  static NSArray *extensions = nil;
  if (!extensions) {
    extensions = [NSArray arrayWithObjects:@"js", nil];
  }
  
  if (URL && [extensions containsObject:[URL pathExtension]])
    return YES;
  
  return NO;
}

@end
