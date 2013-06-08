//
//  DuxSyntaxHighlighter.h
//  Dux
//
//  Created by Abhi Beckert on 2011-10-22.
//  
//  This is free and unencumbered software released into the public domain.
//  For more information, please refer to <http://unlicense.org/>
//

#import <Foundation/Foundation.h>
#import "DuxLanguage.h"
#import "DuxHTMLLanguage.h"
#import "DuxPlainTextLanguage.h"

@interface DuxSyntaxHighlighter : NSObject <NSTextStorageDelegate> {
  NSDictionary *baseAttributes;
  DuxLanguage *baseLanguage;
}

- (id)init; // designated

@property (strong, readonly) NSDictionary *baseAttributes;
@property (strong, readonly) DuxLanguage *baseLanguage;

- (void)setBaseLanguage:(DuxLanguage *)newBaseLanguage forTextStorage:(NSTextStorage *)textStorage;

- (void)updateHighlightingForStorage:(NSTextStorage *)textStorage range:(NSRange)editedRange;

- (DuxLanguage *)languageForRange:(NSRange)range ofTextStorage:(NSTextStorage *)textStorage;
- (DuxLanguageElement *)elementForRange:(NSRange)range ofTextStorage:(NSTextStorage *)textStorage;
- (DuxLanguageElement *)elementAtIndex:(NSUInteger)location longestEffectiveRange:(NSRangePointer)range inTextStorage:(NSTextStorage *)textStorage;

- (BOOL)rangeIsComment:(NSRange)range inTextStorage:(NSTextStorage *)textStorage commentRange:(NSRangePointer)commentRange;

- (void)editorFontDidChange:(NSNotification *)notif;

@end
