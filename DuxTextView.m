//
//  DuxTextView.m
//  Dux
//
//  Created by Abhi Beckert on 2011-10-20.
//  
//  This is free and unencumbered software released into the public domain.
//  For more information, please refer to <http://unlicense.org/>
//

#import "DuxTextView.h"
#import "DuxTextContainer.h"
#import "DuxLineNumberString.h"
#import "DuxScrollViewAnimation.h"
#import "DuxPreferences.h"
#import "NSColor+DuxColors.h"

@implementation DuxTextView

@synthesize highlighter;
@synthesize goToLinePanel;
@synthesize goToLineSearchField;
@synthesize textDocument;
@synthesize highlightedElements;
@synthesize showLineNumbers;
@synthesize showPageGuide;
@synthesize pageGuidePosition;

static NSCharacterSet *newlineCharacterSet;

+ (void)initialize
{
	[super initialize];
	
	newlineCharacterSet = [NSCharacterSet newlineCharacterSet];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
  if (!(self = [super initWithCoder:aDecoder]))
    return nil;
  
  [self initDuxTextView];
  
  return self;
}

- (id)initWithFrame:(NSRect)frameRect textContainer:(NSTextContainer *)container
{
  if (!(self = [super initWithFrame:frameRect textContainer:container]))
    return nil;
  
  [self initDuxTextView];
  
  return self;
}

- (void)initDuxTextView
{
  self.delegate = self;
  
  self.drawsBackground = NO; // disable NSTextView's background so we can draw our own
  
  if ([DuxPreferences editorDarkMode]) {
    self.insertionPointColor = [NSColor colorWithCalibratedWhite:1 alpha:1];
    
    // built in selected text attributes are useless in dark mode, and we cannot set the value of some of them, so instead we disable super's selected text attributes and specify our own ones in setSelectedRange:
    self.selectedTextAttributes = @{};
  }
  
  
  self.showLineNumbers = [DuxPreferences showLineNumbers];
  self.showPageGuide = [DuxPreferences showPageGuide];
  self.pageGuidePosition = [DuxPreferences pageGuidePosition];
  
  DuxTextContainer *container = [[DuxTextContainer alloc] init];
  container.leftGutterWidth = self.showLineNumbers ? 34 : 0;
  container.widthTracksTextView = YES;
  [super setTextContainerInset:NSMakeSize(container.leftGutterWidth / 2, 0)]; // set the inset to half the container's left gutter width
  
  // disable line wrap? currently commented out, because it's a bit buggy
//  container.containerSize = NSMakeSize(FLT_MAX, FLT_MAX);
//  container.widthTracksTextView = NO;
//  self.horizontallyResizable = YES;
  
  if (!self.textStorage.delegate)
    NSLog(@"oops! can't  find syntax highlighter!");
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(syntaxHighlighterDidFinishHighlighting:) name:@"DuxSyntaxHighlighterDidFinishHighlighting" object:self.textStorage.delegate];
  
  // apply the text view
  [self replaceTextContainer:container];
  
  NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];
  [notifCenter addObserver:self selector:@selector(selectionDidChange:) name:NSTextViewDidChangeSelectionNotification object:self];
  [notifCenter addObserver:self selector:@selector(textDidChange:) name:NSTextDidChangeNotification object:self];
  [notifCenter addObserver:self selector:@selector(editorFontDidChange:) name:DuxPreferencesEditorFontDidChangeNotification object:nil];
  [notifCenter addObserver:self selector:@selector(showLineNumbersDidChange:) name:DuxPreferencesShowLineNumbersDidChangeNotification object:nil];
  [notifCenter addObserver:self selector:@selector(showPageGuideDidChange:) name:DuxPreferencesShowPageGuideDidChangeNotification object:nil];
	[notifCenter addObserver:self selector:@selector(showOtherInstancesOfSelectedSymbolDidChange:) name:DuxPreferencesShowOtherInstancesOfSelectedSymbolDidChangeNotification object:nil];
  [notifCenter addObserver:self selector:@selector(pageGuidePositionDidChange:) name:DuxPreferencesPageGuidePositionDidChangeNotification object:nil];
	[notifCenter addObserver:self selector:@selector(editorTabWidthDidChange:) name:DuxPreferencesTabWidthDidChangeNotification object:nil];
	[notifCenter addObserver:self selector:@selector(textContainerSizeDidChange:) name:DuxTextContainerSizeDidChangeNotification object:container];
}

- (NSPoint)textContainerOrigin
{
  DuxTextContainer *container = (id)self.textContainer;
  if (![container isKindOfClass:[DuxTextContainer class]]) // this means the text view isn't yet fully setup
    return [super textContainerOrigin];
  
  return NSMakePoint(container.leftGutterWidth, 0);
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)syntaxHighlighterDidFinishHighlighting:(NSNotification *)notif
{
  if (self.textStorage.length == 0)
    return;
  
  NSUInteger index = (self.selectedRange.location > 0) ? self.selectedRange.location : 0;
  index = MIN(index, self.textStorage.length - 1);
  [self setTypingAttributes:[self.textStorage attributesAtIndex:index effectiveRange:NULL]];
}

- (void)insertNewline:(id)sender
{
  // find the start of the current line
  NSUInteger lineStart = 0;
  NSRange newlineRange = [self.textStorage.string rangeOfCharacterFromSet:newlineCharacterSet options:NSBackwardsSearch range:NSMakeRange(0, self.selectedRange.location)];
  if (newlineRange.location != NSNotFound) {
    lineStart = newlineRange.location + 1;
  }
  
  // grab the whitespace
  NSString *whitespace = @"";
  NSRange whitespaceRange = [self.textStorage.string rangeOfString:@"^[\t ]+" options:NSRegularExpressionSearch range:NSMakeRange(lineStart, self.textStorage.length - lineStart)];
  if (whitespaceRange.location != NSNotFound) {
    whitespace = [self.textStorage.string substringWithRange:whitespaceRange];
  }
  
  // are we about to insert a unix newline immediately after a mac newline? This will create a windows newline, which
  // do nothing as far as the user is concerned, and we need to insert *two* unix newlines
    if (self.selectedRange.location > 0 && [self.string characterAtIndex:self.selectedRange.location - 1] == '\r') {
      [self insertText:[NSString stringForNewlineStyle:DuxNewlineUnix]];
    }
  
  // insert newline
  [self insertText:[NSString stringForNewlineStyle:DuxNewlineUnix]];
  
  // insert whitespace
  if (whitespace) {
    [self insertText:whitespace];
  }
}

- (void)deleteBackward:(id)sender
{
  // when deleting in leading whitespace, indent left instead
	if ([self insertionPointInLeadingWhitespace] && [self.string beginingOfLineAtOffset:self.selectedRange.location] != self.selectedRange.location) {
		[self shiftSelectionLeft:self];
		return;
  }
  
  [super deleteBackward:sender];
}

- (IBAction)jumpToLine:(id)sender
{
  if (!self.goToLinePanel) {
    [NSBundle loadNibNamed:@"JumpToLinePanel" owner:self];
  }
  
  [self.goToLinePanel makeKeyAndOrderFront:sender];
  [self.goToLineSearchField becomeFirstResponder];
}

- (IBAction)goToLinePanelButtonClicked:(id)sender
{
  // figure out what line we are navigating to
  NSInteger targetLine = self.goToLineSearchField.integerValue;
  if (!targetLine) {
    NSBeep();
    return;
  }
  
  // find the line
  int atLine = 1;
  NSString *string = self.textStorage.string;
  NSUInteger stringLength = string.length;
  NSUInteger characterLocation = 0;
  while (atLine < targetLine) {
    characterLocation = [string rangeOfCharacterFromSet:newlineCharacterSet options:NSLiteralSearch range:NSMakeRange(characterLocation, (stringLength - characterLocation))].location;
    
    if (characterLocation == NSNotFound) {
      NSBeep();
      return;
    }
    
    // if we are at a \r character and the next character is a \n, skip the next character
    if (string.length >= characterLocation &&
        [string characterAtIndex:characterLocation] == '\r' &&
        [string characterAtIndex:characterLocation + 1] == '\n') {
      characterLocation++;
    }
    
    atLine++;
    characterLocation++;
  }
  
  // jump to the line
  NSRange lineRange = [string rangeOfLineAtOffset:characterLocation];
  NSUInteger glyphIndex = [self.layoutManager glyphIndexForCharacterAtIndex:lineRange.location];
  NSRect lineRect = [self.layoutManager lineFragmentRectForGlyphAtIndex:glyphIndex effectiveRange:NULL];
  
  [DuxScrollViewAnimation animatedScrollPointToCenter:NSMakePoint(0, NSMinY(lineRect) + (NSHeight(lineRect) / 2)) inScrollView:self.enclosingScrollView];
  
  [self setSelectedRange:lineRange];
  [self.goToLinePanel performClose:self];
}

- (IBAction)commentSelection:(id)sender
{
  // get the selected range
  NSRange commentRange = self.selectedRange;
  
  // if there's no selection, drop back by one character
  if (commentRange.length == 0 && commentRange.location > 0) {
    commentRange.location--;
  }
  
  // if the last character is a newline, select one less character (this gives nicer results in most situations)
  if (commentRange.length > 0 && [self.textStorage.string characterAtIndex:NSMaxRange(commentRange) - 1] == '\n') {
    commentRange.length--;
  }
  
  // is the *entire* selected range commented? If so, uncomment instead
  NSRange uncommentRange;
  if ([self.highlighter rangeIsComment:commentRange inTextStorage:self.textStorage commentRange:&uncommentRange]) {
    
    [self uncomment:uncommentRange];
    return;
  }
  
  // if there is no selected text, comment the whole line
  if (commentRange.length == 0) {
    commentRange = [self.textStorage.string rangeOfLineAtOffset:self.selectedRange.location];
  }
  
  // find the language, and ask it to remove commenting
  DuxLanguage *language = [self.highlighter languageForRange:self.selectedRange ofTextStorage:self.textStorage];
  [language wrapCommentsAroundRange:commentRange ofTextView:self];
}

- (IBAction)uncomment:(NSRange)commentRange
{
  DuxLanguage *language = [self.highlighter languageForRange:self.selectedRange ofTextStorage:self.textStorage];
  [language removeCommentsAroundRange:commentRange ofTextView:self];
}

- (IBAction)shiftSelectionRight:(id)sender
{
	if ([DuxPreferences indentWidth] == 0) // indenting disabled
		return;
	
  // build an array of stings that sholud be inserted
  NSMutableArray *insertRanges = [NSMutableArray array];
	NSMutableArray *insertStrings = [NSMutableArray array];
  
  for (NSValue *selectedRangeValue in self.selectedRanges) {
    for (NSValue *lineRangeValue in [self.string lineEnumeratorForLinesInRange:selectedRangeValue.rangeValue]) {
      NSString *whitespace = [self.string whitespaceForLineBeginingAtLocation:lineRangeValue.rangeValue.location];
      
      // increase the whitespace to the apropriate number of spaces
      NSString *whitespaceChar = [DuxPreferences indentWithSpaces] ? @" " : @"\t";
			NSUInteger targetCount = [self countSpacesInLeadingWhitespace:whitespace] + [DuxPreferences indentWidth];
			targetCount -= targetCount % [DuxPreferences indentWidth];
			
      NSMutableString *newWhitespace = whitespace.mutableCopy;
			[newWhitespace appendString:whitespaceChar];
      while ([self countSpacesInLeadingWhitespace:newWhitespace] < targetCount) {
        [newWhitespace appendString:whitespaceChar];
      }
			
			// if we now have too many spaces, remove the last character and add spaces until we reach the right amount (possible if tabWidth is not exactly modulo indentWidth)
			if ([self countSpacesInLeadingWhitespace:newWhitespace] != targetCount) {
				[newWhitespace replaceCharactersInRange:NSMakeRange(newWhitespace.length - 1, 1) withString:@""];
				while ([self countSpacesInLeadingWhitespace:newWhitespace] < targetCount) {
					[newWhitespace appendString:@" "];
				}
			}
      
      // drop the existing whitespace from the insert string (we're done with it)
			[newWhitespace replaceCharactersInRange:NSMakeRange(0, whitespace.length) withString:@""];
      
      // record it to be inserted later
			NSRange insertRange = NSMakeRange(lineRangeValue.rangeValue.location + whitespace.length, 0);
      [insertRanges addObject:[NSValue valueWithRange:insertRange]];
			[insertStrings addObject:newWhitespace.copy];
    }
  }
	
	// give parent class a chance to cancel this edit, and let it do it's undo manager stuff
	if (![self shouldChangeTextInRanges:insertRanges replacementStrings:insertStrings]) {
		return;
	}
  
  // insert the strings, maintaining the current selected range
  NSArray *selectedRanges = self.selectedRanges;
  
  NSUInteger insertionOffset = 0;
	NSUInteger insertIndex;
  for (insertIndex = 0; insertIndex < insertRanges.count; insertIndex++) {
    NSString *whitespace = [insertStrings objectAtIndex:insertIndex];
		NSRange insertRange = [[insertRanges objectAtIndex:insertIndex] rangeValue];
		insertRange.location += insertionOffset;
    
    [self replaceCharactersInRange:insertRange withString:whitespace];
    
    insertionOffset += whitespace.length;
    
    NSMutableArray *newSelectedRanges = [NSMutableArray array];
    for (NSValue *selectedRangeValue in selectedRanges) {
      NSRange selectedRange = selectedRangeValue.rangeValue;
      
      if (NSMaxRange(selectedRange) < insertRange.location) {
        // selected range before insertion. do nothing
      } else if ((selectedRange.length == 0 && selectedRange.location >= insertRange.location) || (selectedRange.length > 0 && selectedRange.location > insertRange.location)) {
        // selected range after insertion. increase location by insertion size
        selectedRange.location += whitespace.length;
      } else {
        // selected range includes insertion. extend it's length
        selectedRange.length += whitespace.length;
      }
      [newSelectedRanges addObject:[NSValue valueWithRange:selectedRange]];
    }
    selectedRanges = [newSelectedRanges copy];
  }
  
  // restore modified selected ranges
  [self setSelectedRanges:selectedRanges];
}

- (IBAction)shiftSelectionLeft:(id)sender
{
	if ([DuxPreferences indentWidth] == 0) // indenting disabled
		return;
	
  // build an array of stings that sholud be inserted
	NSMutableArray *insertRanges = [NSMutableArray array];
	NSMutableArray *insertStrings = [NSMutableArray array];
  
  for (NSValue *selectedRangeValue in self.selectedRanges) {
    for (NSValue *lineRangeValue in [self.string lineEnumeratorForLinesInRange:selectedRangeValue.rangeValue]) {
      NSString *whitespace = [self.string whitespaceForLineBeginingAtLocation:lineRangeValue.rangeValue.location];
      
			// figure out the apropriate indent width
			NSUInteger targetCount = [self countSpacesInLeadingWhitespace:whitespace];
			if (targetCount < [DuxPreferences indentWidth]) {
				targetCount = 0;
			} else {
				targetCount -= [DuxPreferences indentWidth];
			}
			targetCount += targetCount % [DuxPreferences indentWidth];
			
      // reduce the whitespace to the apropriate number of spaces
      NSMutableString *newWhitespace = whitespace.mutableCopy;
      while ([self countSpacesInLeadingWhitespace:newWhitespace] > targetCount) {
        [newWhitespace replaceCharactersInRange:NSMakeRange(newWhitespace.length -1, 1) withString:@""];
      }
			NSRange insertRange = NSMakeRange(lineRangeValue.rangeValue.location + newWhitespace.length, whitespace.length - newWhitespace.length);
			NSString *insertString = @"";
			
			// if we now don't have enough spaces, add some until we have the right amount (this can happen if there's an odd combination of tabs/spaces)
			while ([self countSpacesInLeadingWhitespace:newWhitespace] < targetCount) {
				insertString = [insertString stringByAppendingString:@" "];
			}
      
      // record it to be inserted later
			[insertRanges addObject:[NSValue valueWithRange:insertRange]];
			[insertStrings addObject:insertString];
    }
  }
	
	// give parent class a chance to cancel this edit, and let it do it's undo manager stuff
	if (![self shouldChangeTextInRanges:insertRanges replacementStrings:insertStrings]) {
		return;
	}
  
  // insert the strings, maintaining the current selected range
  NSArray *selectedRanges = self.selectedRanges;
  
  NSInteger insertionOffset = 0;
	NSUInteger insertIndex;
  for (insertIndex = 0; insertIndex < insertRanges.count; insertIndex++) {
    NSString *whitespace = [insertStrings objectAtIndex:insertIndex];
		NSRange insertRange = [[insertRanges objectAtIndex:insertIndex] rangeValue];
		insertRange.location += insertionOffset;
    
    [self replaceCharactersInRange:insertRange withString:whitespace];
    
    insertionOffset -= (insertRange.length - whitespace.length);
    
    NSMutableArray *newSelectedRanges = [NSMutableArray array];
    for (NSValue *selectedRangeValue in selectedRanges) {
      NSRange selectedRange = selectedRangeValue.rangeValue;
      
      if (NSMaxRange(selectedRange) < insertRange.location) {
        // selected range before insertion. do nothing
      } else if (selectedRange.location > insertRange.location) {
        // selected range after insertion. reduce location by insertion size
        selectedRange.location -= (insertRange.length - whitespace.length);
      } else {
        // selected range includes insertion. reduce it's length
				if (selectedRange.length > (insertRange.length - whitespace.length)) {
					selectedRange.length -= (insertRange.length - whitespace.length);
				} else {
					selectedRange.length = 0;
				}
      }
			
			if (selectedRange.length > 0 || newSelectedRanges.count == 0) // can only have a single zero length range
				[newSelectedRanges addObject:[NSValue valueWithRange:selectedRange]];
    }
    selectedRanges = [newSelectedRanges copy];
  }
  
  // restore modified selected ranges
  [self setSelectedRanges:selectedRanges];
}

- (void)setSelectedRanges:(NSArray *)ranges affinity:(NSSelectionAffinity)affinity stillSelecting:(BOOL)stillSelectingFlag
{
  // built in selected text attributes are useless in dark mode, and we cannot set the value of some of them, so instead we disable super's selected text attributes and specify our own ones in setSelectedRange:
  if ([DuxPreferences editorDarkMode]) {
    for (NSValue *value in self.selectedRanges) {
      if (value.rangeValue.length == 0)
        continue;
      
      [self.textStorage removeAttribute:NSBackgroundColorAttributeName range:value.rangeValue];
    }
    
    // apply new bacgkround colors
    for (NSValue *value in ranges) {
      if (value.rangeValue.length == 0)
        continue;
      
      [self.textStorage addAttribute:NSBackgroundColorAttributeName value:[NSColor colorWithCalibratedRed:0.504 green:0.710 blue:1.000 alpha:0.3] range:value.rangeValue];
    }
  }
  
  [super setSelectedRanges:ranges affinity:affinity stillSelecting:stillSelectingFlag];
}

- (NSArray *)completionsForPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index
{
  NSTextStorage *textStorage = self.textStorage;
  NSString *string = textStorage.string;
  NSUInteger stringLength = string.length;
  
  // figure out the partial word
  NSString *partialWord = [string substringWithRange:charRange];
  NSString *wordPattern = [NSString stringWithFormat:@"\\b%@[a-zA-Z0-9_]+", [NSRegularExpression escapedPatternForString:partialWord]];
  NSRegularExpression *wordExpression = [[NSRegularExpression alloc] initWithPattern:wordPattern options:0 error:NULL];
  
  // find every word in the current document that begins with the same string
  NSMutableSet *completions = [NSMutableSet set];
  __block NSString *completion;
  [wordExpression enumerateMatchesInString:string options:0 range:NSMakeRange(0, stringLength) usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop){
    completion = [string substringWithRange:match.range];
    
    if ([completions containsObject:completion]) {
      return;
    }
    
    [completions addObject:completion];
  }];
  
  return [completions sortedArrayUsingDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"self" ascending:YES]]];
}

- (NSUInteger)countSpacesInLeadingWhitespace:(NSString *)lineString
{
  NSUInteger spacesWide = 0;
  NSUInteger charLocation;
  for (charLocation = 0; charLocation < lineString.length; charLocation++) {
    switch ([lineString characterAtIndex:charLocation]) {
      case ' ':
        spacesWide++;
        break;
      case '\t':
        spacesWide++;
        while (spacesWide % [DuxPreferences tabWidth] != 0) {
          spacesWide++;
        }
        break;
      default: // found a non
        charLocation = lineString.length;
    }
  }
  
  return spacesWide;
}

- (IBAction)showCompletions:(id)sender
{
  [self complete:sender];
}

- (IBAction)paste:(id)sender
{
  NSArray *copiedItems = [[NSPasteboard generalPasteboard] readObjectsForClasses:[NSArray arrayWithObject:[NSString class]] options:[NSDictionary dictionary]];
  if (copiedItems == nil || copiedItems.count == 0) {
    NSBeep();
    return;
  }
  
  NSString *pasteString = [copiedItems objectAtIndex:0];
  pasteString = [pasteString stringByReplacingNewlinesWithNewline:DuxNewlineUnix];
  
  [self breakUndoCoalescing];
  [self insertText:pasteString];
  [self breakUndoCoalescing];
}

- (void)insertText:(id)insertString
{
  // built in selected text attributes are useless in dark mode, and we cannot set the value of some of them, so instead we disable super's selected text attributes and specify our own ones in setSelectedRange:
  if ([DuxPreferences editorDarkMode]) {
    for (NSValue *value in self.selectedRanges) {
      if (value.rangeValue.length == 0)
        continue;
      
      [self.textStorage removeAttribute:NSBackgroundColorAttributeName range:value.rangeValue];
    }
  }
  
  [super insertText:insertString];
}

- (void)insertSnippet:(NSString *)snippet
{
  if (snippet.length == 0)
    return;
  
  NSRange selectedRangeAfterInsert = NSMakeRange(self.selectedRange.location + snippet.length, 0);
  
  NSRange snippetSelectedRange = [snippet rangeOfString:@"$0"];
  if (snippetSelectedRange.location != NSNotFound) {
    NSString *selectedString = @"";
    if (self.selectedRange.length > 0) {
      selectedString = [self.textStorage.string substringWithRange:self.selectedRange];
    }
    
    snippet = [snippet stringByReplacingCharactersInRange:snippetSelectedRange withString:selectedString];
    
    selectedRangeAfterInsert = NSMakeRange(self.selectedRange.location + snippetSelectedRange.location, selectedString.length);
  }
  
  
  [self insertText:snippet];
  self.selectedRange = selectedRangeAfterInsert;
}

- (BOOL)smartInsertDeleteEnabled
{
  return NO;
}

- (BOOL)isAutomaticQuoteSubstitutionEnabled
{
  return NO;
}

- (BOOL)isAutomaticLinkDetectionEnabled
{
  return NO;
}

- (BOOL)isAutomaticDataDetectionEnabled
{
  return NO;
}

- (BOOL)isAutomaticDashSubstitutionEnabled
{
  return NO;
}

- (BOOL)isAutomaticTextReplacementEnabled
{
  return NO;
}

- (BOOL)isAutomaticSpellingCorrectionEnabled
{
  return NO;
}

- (void)keyDown:(NSEvent *)theEvent
{
  
  // handle other key
  switch ([[theEvent charactersIgnoringModifiers] characterAtIndex:0]) {
    case NSLeftArrowFunctionKey:
      if (!([theEvent modifierFlags] & NSControlKeyMask))
        break;
      
      if ([theEvent modifierFlags] & NSShiftKeyMask) {
        [self moveSubwordBackwardAndModifySelection:self];
      } else {
        [self moveSubwordBackward:self];
      }
      return;
    case NSRightArrowFunctionKey:;
      if (!([theEvent modifierFlags] & NSControlKeyMask))
        break;
      
      if ([theEvent modifierFlags] & NSShiftKeyMask) {
        [self moveSubwordForwardAndModifySelection:self];
      } else {
        [self moveSubwordForward:self];
      }
      return;
    case NSDeleteCharacter: // "delete" on mac keyboards, but "backspace" on others
      if (!([theEvent modifierFlags] & NSControlKeyMask))
        break;
      
      [self deleteSubwordBackward:self];
      return;
    case NSDeleteFunctionKey: // "delete forward" on mac keyboards, but "delete" on others
      if (!([theEvent modifierFlags] & NSControlKeyMask))
        break;
      
      [self deleteSubwordForward:self];
      return;
    case NSTabCharacter:
    case 25: // shift-tab
      if (![self tabShouldIndentWithCurrentSelectedRange]) {
        break;
      }
      
      if (theEvent.modifierFlags & NSShiftKeyMask) {
        [self shiftSelectionLeft:self];
      } else {
        [self shiftSelectionRight:self];
      }
      return;
    
  }
  
  [super keyDown:theEvent];
}

- (BOOL)insertionPointInLeadingWhitespace
{
	if (self.selectedRanges.count > 1)
		return NO;
	
  if (self.selectedRange.length != 0)
    return NO;
  
  if (self.selectedRange.location == 0)
    return YES;
  
  NSUInteger currentLineStart = [self.string rangeOfLineAtOffset:self.selectedRange.location].location;
  if (currentLineStart == self.selectedRange.location)
    return YES;
  
  NSCharacterSet *nonWhitespaceCharacterSet = [[NSCharacterSet whitespaceCharacterSet] invertedSet];
  NSUInteger charLocation = [self.string rangeOfCharacterFromSet:nonWhitespaceCharacterSet options:NSLiteralSearch range:NSMakeRange(currentLineStart, self.selectedRange.location - currentLineStart)].location;
  
  return charLocation == NSNotFound;
}

- (BOOL)tabShouldIndentWithCurrentSelectedRange
{
  if ([DuxPreferences tabIndentBehaviour] == DuxTabAlwaysIndents)
    return YES;
  
  if ([DuxPreferences tabIndentBehaviour] == DuxTabNeverIndents)
    return NO;

  return [self insertionPointInLeadingWhitespace];
}

- (NSUInteger)findBeginingOfSubwordStartingAt:(NSUInteger)offset
{
  // find one of three possibilities:
  //  - the begining of a single word, all uppercase, that is at the end of the search range (parenthesis set 2)
  //  - a point where a non-lowercase character is followed by a lowercase character (parenthesis set 4)
  NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:@"([^a-z0-9]([A-Z]+[^a-z0-9]*$))|(^|[^a-z0-9])([a-z0-9])" options:0 error:NULL];
  
  // we only work with one line at a time, to make the regex faster
  NSRange lineRange = [self.textStorage.string rangeOfLineAtOffset:offset];
  NSString *searchString = [self.textStorage.string substringWithRange:lineRange];
  
  // prepare search range
  NSUInteger insertionPoint = offset - lineRange.location;
  NSRange searchRange = NSMakeRange(0, insertionPoint);
  
  // we may need to try the search again on the previous line
  NSUInteger newInsertionPoint = 0;
  while (YES) {
    // don't bother searching from the begining of the line... try again on the previous line (unless we are at the begining of the file!)
    if (insertionPoint == 0 && lineRange.location != 0) {
      lineRange = [self.textStorage.string rangeOfLineAtOffset:lineRange.location - 1];
      searchString = [self.textStorage.string substringWithRange:lineRange];
      insertionPoint = lineRange.length - 1;
      searchRange = NSMakeRange(0, lineRange.length);
      continue;
    }
    
    // find the last match
    NSTextCheckingResult *match = [[expression matchesInString:searchString options:0 range:searchRange] lastObject];
    
    // which match do we want?
    newInsertionPoint = 0;
    if (match && [match rangeAtIndex:2].location != NSNotFound) {
      newInsertionPoint = [match rangeAtIndex:2].location;
    } else if (match && [match rangeAtIndex:4].location != NSNotFound) {
      newInsertionPoint = [match rangeAtIndex:4].location;
    } else { // no match found at all, try again on the previous line
      if (lineRange.location != 0) { // make sure we aren't at the begining of the file
        lineRange = [self.textStorage.string rangeOfLineAtOffset:lineRange.location - 1];
        searchString = [self.textStorage.string substringWithRange:lineRange];
        insertionPoint = lineRange.length - 1;
        searchRange = NSMakeRange(0, lineRange.length);
        continue;
      }
    }
    
    // if we are in between an uppercase letter and a lowercase letter, than we need to drop 1 from the index
    if ([[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember:[searchString characterAtIndex:newInsertionPoint - 1]]) {
      newInsertionPoint--;
    }
    
    break;
  }
  
  return newInsertionPoint + lineRange.location;
}

- (NSUInteger)findEndOfSubwordStartingAt:(NSUInteger)offset
{
  // find one of two possibilities:
  //  - the end of a single word, all uppercase, that is at the begining of the search range (parenthesis set 2)
  //  - a point where a lowercase character is followed by a non-lowercase character (parenthesis set 4)
  NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:@"((^[^a-z0-9]*[A-Z]+)[^A-Z])|([a-z0-9])($|[^a-z0-9])" options:0 error:NULL];
  
  // we only work with one line at a time, to make the regex faster
  NSRange lineRange = [self.textStorage.string rangeOfLineAtOffset:offset];
  NSString *searchString = [self.textStorage.string substringWithRange:lineRange];
  
  // prepare search range
  NSUInteger insertionPoint = offset - lineRange.location;
  NSRange searchRange = NSMakeRange(MIN(insertionPoint + 1, searchString.length), searchString.length == 0 ? 0 : (searchString.length - (insertionPoint + 1)));
  
  // we may need to try the search again on the previous line
  NSUInteger newInsertionPoint = searchString.length;
  while (YES) {
    // don't bother searching from the begining of the line... try again on the next line (unless we are at the end of the file!)
    if (insertionPoint >= (searchString.length - 1) && (NSMaxRange(lineRange) < self.textStorage.string.length)) {
      lineRange = [self.textStorage.string rangeOfLineAtOffset:NSMaxRange(lineRange) + 1];
      searchString = [self.textStorage.string substringWithRange:lineRange];
      insertionPoint = 0;
      searchRange = NSMakeRange(0, searchString.length);
      continue;
    }
    
    // find the last match
    NSTextCheckingResult *match = [expression firstMatchInString:searchString options:0 range:searchRange];
    
    // which match do we want?
    newInsertionPoint = searchString.length;
    if (match && [match rangeAtIndex:2].location != NSNotFound) {
      newInsertionPoint = NSMaxRange([match rangeAtIndex:2]);
    } else if (match && [match rangeAtIndex:4].location != NSNotFound) {
      newInsertionPoint = [match rangeAtIndex:4].location;
    } else { // no match found at all, try again on the previous line
      if (NSMaxRange(lineRange) < self.textStorage.string.length) { // make sure we aren't at the begining of the file
        lineRange = [self.textStorage.string rangeOfLineAtOffset:NSMaxRange(lineRange) + 1];
        searchString = [self.textStorage.string substringWithRange:lineRange];
        insertionPoint = 0;
        searchRange = NSMakeRange(0, searchString.length);
        continue;
      }
    }
    
    // if we are in between an uppercase letter and a lowercase letter, than we need to drop 1 from the index
    if (searchString.length > 0) {
      BOOL prevCharIsUppercase = [[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember:[searchString characterAtIndex:newInsertionPoint - 1]];
      BOOL nextCharIsLowercase = [[NSCharacterSet lowercaseLetterCharacterSet] characterIsMember:[searchString characterAtIndex:MIN(newInsertionPoint, searchString.length - 1)]];
      if (prevCharIsUppercase && nextCharIsLowercase) {
        newInsertionPoint--;
      }
    }
    
    break;
  }
  
  return newInsertionPoint + lineRange.location;
}

- (void)moveSubwordBackward:(id)sender
{
  NSMutableArray *newSelectedRanges = [NSMutableArray array];
  
  for (NSValue *rangeValue in self.selectedRanges) {
    NSUInteger newInsertionPoint = [self findBeginingOfSubwordStartingAt:rangeValue.rangeValue.location];
    
    NSRange newRange = NSMakeRange(newInsertionPoint, 0);
    
    [newSelectedRanges addObject:[NSValue valueWithRange:newRange]];
  }
  
  [self setSelectedRanges:[newSelectedRanges copy]];
}

- (void)moveSubwordBackwardAndModifySelection:(id)sender
{
  NSMutableArray *newSelectedRanges = [NSMutableArray array];
  
  for (NSValue *rangeValue in self.selectedRanges) {
    NSUInteger newInsertionPoint = [self findBeginingOfSubwordStartingAt:rangeValue.rangeValue.location];
    
    NSRange newRange = NSMakeRange(newInsertionPoint, NSMaxRange(rangeValue.rangeValue) - newInsertionPoint);
    
    [newSelectedRanges addObject:[NSValue valueWithRange:newRange]];
  }
  
  [self setSelectedRanges:[newSelectedRanges copy]];
}

- (void)moveSubwordForward:(id)sender
{
  NSMutableArray *newSelectedRanges = [NSMutableArray array];
  
  for (NSValue *rangeValue in self.selectedRanges) {
    NSUInteger newInsertionPoint = [self findEndOfSubwordStartingAt:NSMaxRange(rangeValue.rangeValue)];
    
    NSRange newRange = NSMakeRange(newInsertionPoint, 0);
    
    [newSelectedRanges addObject:[NSValue valueWithRange:newRange]];
  }
  
  [self setSelectedRanges:[newSelectedRanges copy]];
}

- (void)moveSubwordForwardAndModifySelection:(id)sender
{
  NSMutableArray *newSelectedRanges = [NSMutableArray array];
  
  for (NSValue *rangeValue in self.selectedRanges) {
    NSUInteger newInsertionPoint = [self findEndOfSubwordStartingAt:NSMaxRange(rangeValue.rangeValue)];
    
    NSRange newRange = NSMakeRange(rangeValue.rangeValue.location, newInsertionPoint - rangeValue.rangeValue.location);
    
    [newSelectedRanges addObject:[NSValue valueWithRange:newRange]];
  }
  
  [self setSelectedRanges:[newSelectedRanges copy]];
}

- (void)deleteSubwordBackward:(id)sender
{
  if (self.selectedRanges.count > 1 || self.selectedRange.length > 0)
    return [self deleteBackward:sender];
  
  NSUInteger deleteOffset = [self findBeginingOfSubwordStartingAt:self.selectedRange.location];
  
  NSRange newRange = NSMakeRange(deleteOffset, self.selectedRange.location - deleteOffset);
  
  [self insertText:@"" replacementRange:newRange];
}

- (void)deleteSubwordForward:(id)sender
{
  if (self.selectedRanges.count > 1 || self.selectedRange.length > 0)
    return [self deleteForward:sender];
  
  NSUInteger deleteOffset = [self findEndOfSubwordStartingAt:self.selectedRange.location];
  
  NSRange newRange = NSMakeRange(self.selectedRange.location, deleteOffset - self.selectedRange.location);
  
  [self insertText:@"" replacementRange:newRange];
}

- (void)delete:(id)sender
{
  [self deleteToBeginningOfLine:sender];
}

- (void)duplicate:(id)sender
{
  NSArray *ranges;
  NSRange newSelectionSubrange = NSMakeRange(NSNotFound, 0); // if NSNotFound, new selection will be the inserted text. else new selection will be a subrange of the inserted text
  if (self.selectedRange.length == 0) {
    NSRange lineRange = [self.string rangeOfLineAtOffset:self.selectedRange.location];
    ranges = [NSArray arrayWithObject:[NSValue valueWithRange:lineRange]];
    newSelectionSubrange = NSMakeRange(self.selectedRange.location - lineRange.location, 0);
  } else {
    ranges = self.selectedRanges;
  }
  
  NSMutableArray *insertStrings = [NSMutableArray array];
  NSMutableArray *insertRanges = [NSMutableArray array];
  for (NSValue *rangeValue in ranges) {
    [insertStrings addObject:[self.string substringWithRange:rangeValue.rangeValue]];
    [insertRanges addObject:[NSValue valueWithRange:NSMakeRange(NSMaxRange(rangeValue.rangeValue), 0)]];
  }
  
  // give parent class a chance to cancel this edit, and let it do it's undo manager stuff
	if (![self shouldChangeTextInRanges:insertRanges replacementStrings:insertStrings]) {
		return;
	}
  
  // insert the strings
  NSUInteger insertionOffset = 0;
	NSUInteger insertIndex;
  NSMutableArray *newSelectedRanges = [NSMutableArray array];
  NSString *newlineString = [NSString stringForNewlineStyle:DuxNewlineUnix];
  for (insertIndex = 0; insertIndex < insertRanges.count; insertIndex++) {
    NSString *insertString = [insertStrings objectAtIndex:insertIndex];
		NSRange insertRange = [[insertRanges objectAtIndex:insertIndex] rangeValue];
		insertRange.location += insertionOffset;
    
    // if the range ends at the end of the line (or end of file), add a newline first
    if (self.string.length == NSMaxRange(self.selectedRange) || NSMaxRange(insertRange) == [self.string endOfLineAtOffset:NSMaxRange(insertRange)]) {
      [self replaceCharactersInRange:insertRange withString:newlineString];
      insertRange.location += newlineString.length;
    }
    
    // do the insert
    [self replaceCharactersInRange:insertRange withString:insertString];
    
    // update selection
    if (newSelectionSubrange.location == NSNotFound) {
      [newSelectedRanges addObject:[NSValue valueWithRange:NSMakeRange(insertRange.location, insertString.length)]];
    } else {
      [newSelectedRanges addObject:[NSValue valueWithRange:NSMakeRange(insertRange.location + newSelectionSubrange.location, newSelectionSubrange.length)]];
    }
    
    insertionOffset += insertString.length;
  }
  [self setSelectedRanges:[newSelectedRanges copy]];
}

- (void)setNeedsDisplayInRect:(NSRect)rect avoidAdditionalLayout:(BOOL)flag
{
  // force all screen draws to be the full width
  rect.origin.x = 0;
  rect.size.width = self.bounds.size.width;
  
  [super setNeedsDisplayInRect:rect avoidAdditionalLayout:flag];
}

- (void)drawRect:(NSRect)dirtyRect
{
	NSRect documentVisibleRect = self.enclosingScrollView.documentVisibleRect;
	NSLayoutManager *layoutManager = self.layoutManager;
	NSTextContainer *textContainer = self.textContainer;
  
  // background
  [self.backgroundColor set];
  NSRectFill(dirtyRect);
  
  // page guide
  if (self.showPageGuide) {
if ([DuxPreferences editorDarkMode]) {
    [[NSColor colorWithDeviceWhite:1 alpha:0.1] set];
} else {
    [[NSColor colorWithDeviceWhite:0.85 alpha:1] set];
}
    float position = self.pageGuidePosition;
    if (self.showLineNumbers)
      position += 34;
    position += 0.5;
    [NSBezierPath strokeLineFromPoint:NSMakePoint(position, NSMinY(documentVisibleRect)) toPoint:NSMakePoint(position, NSMaxY(documentVisibleRect))];
  }
  
  // draw highlighted elements and ranges
  NSRange glyphRange;
  NSRectArray glyphRects;
  NSUInteger glyphRectsIndex;
  NSUInteger glyphRectsCount;
if ([DuxPreferences editorDarkMode]) {
  [[NSColor colorWithCalibratedRed:0.173 green:0.151 blue:0.369 alpha:1.000] set];
} else {
  [[NSColor colorWithCalibratedRed:0.973 green:0.951 blue:0.769 alpha:1.000] set];
}
  float glyphRectExtraX = (self.showLineNumbers) ? 33.5 : 0;
  for (NSValue *range in self.highlightedElements) {
    glyphRange = [layoutManager glyphRangeForCharacterRange:range.rangeValue actualCharacterRange:NULL];
    
    glyphRects = [layoutManager rectArrayForGlyphRange:glyphRange withinSelectedGlyphRange:glyphRange inTextContainer:textContainer rectCount:&glyphRectsCount];
    for (glyphRectsIndex = 0; glyphRectsIndex < glyphRectsCount; glyphRectsIndex++) {
      CGRect glyphRect = glyphRects[glyphRectsIndex];
      glyphRect.origin.x += glyphRectExtraX;
      [NSBezierPath fillRect:glyphRect];
    }
  }
  
  [[NSColor colorWithDeviceRed:0.35 green:0.54 blue:0.93 alpha:0.2] set];
  for (NSValue *range in self.highlightedRanges) {
    glyphRange = [layoutManager glyphRangeForCharacterRange:range.rangeValue actualCharacterRange:NULL];
    
    glyphRects = [layoutManager rectArrayForGlyphRange:glyphRange withinSelectedGlyphRange:glyphRange inTextContainer:textContainer rectCount:&glyphRectsCount];
    CGFloat y = FLT_MAX;
    CGFloat height = 0;
    CGRect glyphRect;
    for (glyphRectsIndex = 0; glyphRectsIndex < glyphRectsCount; glyphRectsIndex++) {
      glyphRect = glyphRects[glyphRectsIndex];
      
      if (glyphRect.origin.y < y)
        y = glyphRect.origin.y;
      if (y + height < glyphRect.origin.y + glyphRect.size.height) {
        height = ((glyphRect.origin.y + glyphRect.size.height) - y);
      }
    }
    y += 15;
    if (height > 15.1) {
      height -= 15;
    }
    
    glyphRect = CGRectMake(-1, floor(y), self.bounds.size.width + 2, ceil(height));
    
    [NSBezierPath fillRect:glyphRect];
  }
  
  // line numbers
  if (self.showLineNumbers) {
		// background
//if ([DuxPreferences editorDarkMode]) {
//    [[NSColor colorWithDeviceWhite:0.2 alpha:0] set];
//#else
//    [[NSColor colorWithDeviceWhite:0.85 alpha:1] set];
//#endif
//    [NSBezierPath strokeLineFromPoint:NSMakePoint(33.5, NSMinY(documentVisibleRect)) toPoint:NSMakePoint(33.5, NSMaxY(documentVisibleRect))];
//if ([DuxPreferences editorDarkMode]) {
//    [[NSColor colorWithDeviceWhite:0.1 alpha:0] set];
//#else
//    [[NSColor colorWithDeviceWhite:0.95 alpha:1] set];
//#endif
//    [NSBezierPath fillRect:NSMakeRect(0, NSMinY(documentVisibleRect), 33.5, NSMaxY(documentVisibleRect))];
    
    // line numbers
    [self drawLineNumbersInRect:dirtyRect];
  }
  
  [super drawRect:dirtyRect];
}

- (void)selectionDidChange:(NSNotification *)notif
{
  [self updateHighlightedElements];
}

- (void)textDidChange:(NSNotification *)notif
{
  [self updateHighlightedElements];
}

- (void)updateHighlightedElements
{
  // We only do highlighting when the main thread isn't very busy dealing with user activity in our text view.
  // By delaying this method for a short moment, and when it is run checking if this really is the most recent
  // call, we ensure this will only happen when the user stops typing, particularly if the document is complicated
  // and typing imposes a lot of CPU activity.
  
  _lastUupdateHighlightedElements++;
  NSUInteger thisUpdate = _lastUupdateHighlightedElements;
  
  dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.05 * NSEC_PER_SEC); // weird drawing glitches if we do this immediately
  dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
    if (thisUpdate != _lastUupdateHighlightedElements)
      return;
    
    NSTextStorage *textStorage = self.textStorage;
    
    if (self.highlightedElements.count > 0) {
      self.highlightedElements = [NSSet set];
      [self setNeedsDisplay:YES];
    }
		
		if (![DuxPreferences showOtherInstancesOfSelectedSymbol]) {
			return;
		}
    
    if (self.selectedRange.length != 0 || self.selectedRange.location == 0 || self.selectedRange.location > self.textStorage.length)
      return;
    
    NSString *string = self.textStorage.string;
    NSUInteger stringLength = string.length;
    NSUInteger selectedLocation = self.selectedRange.location;
    
    // find the current selected element
    NSRange elementRange;
    DuxLanguageElement *element = [self.highlighter elementAtIndex:selectedLocation - 1 longestEffectiveRange:&elementRange inTextStorage:textStorage];
    NSString *elementString = [self.textStorage.string substringWithRange:elementRange];
    
    if (!element.shouldHighlightOtherIdenticalElements) {
      return;
    }
    
    // find other identical elements
    NSUInteger searchStart = selectedLocation > 10000 ? self.selectedRange.location - 10000 : 0;
    NSUInteger searchEnd = MIN(selectedLocation + 10000, stringLength - 1);
    NSRange otherElementRange;
    DuxLanguageElement *otherElement;
    NSMutableSet *newHighlightedElements = [NSMutableSet set];
    while (searchStart <= searchEnd) {
      otherElementRange = [string rangeOfString:elementString options:NSLiteralSearch range:NSMakeRange(searchStart, stringLength - searchStart)];
      if (otherElementRange.location == NSNotFound)
        break;
      
      searchStart = NSMaxRange(otherElementRange);
      
      otherElement = [self.highlighter elementAtIndex:otherElementRange.location longestEffectiveRange:&otherElementRange inTextStorage:textStorage];
      if (otherElementRange.length != elementRange.length)
        continue;
      
      if (otherElement != element)
        continue;
      
      [newHighlightedElements addObject:[NSValue valueWithRange:otherElementRange]];
    }
    self.highlightedElements = newHighlightedElements.count > 1 ? [newHighlightedElements copy] : [NSSet set];
    
    if (self.highlightedElements.count > 0) {
      [self setNeedsDisplay:YES];
    }
  });
}

- (void)setHighlightedRanges:(NSSet *)highlightedRanges
{
  _highlightedRanges = highlightedRanges;
  
  [self setNeedsDisplay:YES];
}

- (void)processLines
{
  NSString *string = self.string;
  if (lastProcessLinesStringHash == string.hash)
    return;
  
  NSUInteger stringLength = string.length;
  NSUInteger characterIndex = 0;
  NSUInteger lineIndex = 0;
  
  if (stringLength == 0) {
    while (lineIndex < 99999) {
      if (characterIndex >= stringLength) {
        lineCharacterIndexes[lineIndex] = NSNotFound;
        lineIndex++;
        continue;
      }
    }
    return;
  }
  
  NSTextStorage *textStorage = self.textStorage;
  BOOL didBeginEditingTextStorage = NO;
  
  NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
  [paragraphStyle setTabStops:[NSArray array]];
  [paragraphStyle setAlignment:NSLeftTextAlignment];
  [paragraphStyle setBaseWritingDirection:NSWritingDirectionLeftToRight];
  [paragraphStyle setLineBreakMode:NSLineBreakByWordWrapping];
  
  float spaceWidth = [@" " sizeWithAttributes:[textStorage attributesAtIndex:0 effectiveRange:NULL]].width;
  [paragraphStyle setDefaultTabInterval:spaceWidth * [DuxPreferences tabWidth]];
  float headIndentWidth = spaceWidth * ([DuxPreferences tabWidth] * 2);
  
  NSUInteger whitespaceCount;
  NSNumber *oldWhitespaceCount;
  NSUInteger tabWidth = [DuxPreferences tabWidth];
  
  while (lineIndex < 99999) {
    if (characterIndex >= stringLength) {
      lineCharacterIndexes[lineIndex] = NSNotFound;
      lineIndex++;
      continue;
    }
    
    // are we in between a CR and LF character? (windows newlines)
    if (characterIndex > 0 && [string characterAtIndex:characterIndex - 1] == '\r' && [string characterAtIndex:characterIndex] == '\n') {
      characterIndex++;
    }
    
    // record line range
    NSRange lineRange = NSMakeRange(characterIndex, [string endOfLineAtOffset:characterIndex] - characterIndex);
    lineCharacterIndexes[lineIndex] = lineRange.location;
    
    // count number of spaces in leading whitespace
    if (lineRange.length > 0) {
      whitespaceCount = 0;
      for (characterIndex = lineRange.location; characterIndex < NSMaxRange(lineRange); characterIndex++) {
        switch ([string characterAtIndex:characterIndex]) {
          case ' ':
            whitespaceCount++;
            break;
          case '\t':
            whitespaceCount++;
            while (whitespaceCount % tabWidth != 0) {
              whitespaceCount++;
            }
            break;
          default: // found a non-whitespace char
            characterIndex = NSMaxRange(lineRange);
        }
      }
      
      // if it isn't already correct, update head intent to match whitespace
      oldWhitespaceCount = [textStorage attribute:@"DuxEditorLeadingWhitespaceCount" atIndex:lineRange.location effectiveRange:0];
      if (!oldWhitespaceCount || [oldWhitespaceCount integerValue] != whitespaceCount) {
        if (!didBeginEditingTextStorage) {
          didBeginEditingTextStorage = YES;
          [textStorage beginEditing];
        }
        
        [textStorage addAttribute:@"DuxEditorLeadingWhitespaceCount" value:[NSNumber numberWithInteger:whitespaceCount] range:lineRange];
        [paragraphStyle setHeadIndent:headIndentWidth + (whitespaceCount * spaceWidth)];
        [textStorage addAttribute:NSParagraphStyleAttributeName value:[paragraphStyle copy] range:lineRange];
      }
    }
    
    characterIndex = NSMaxRange(lineRange) + 1;
    lineIndex++;
  }
  if (didBeginEditingTextStorage) {
    [textStorage endEditing];
  }
  
  lastProcessLinesStringHash = string.hash;  
}

- (void)drawLineNumbersInRect:(NSRect)targetRect
{
	// init
  [self processLines];
  NSLayoutManager *layoutManager = self.layoutManager;
	NSTextContainer *textContainer = self.textContainer;
	
  NSUInteger lineIndex = 0;
  NSInteger characterIndex = 0;
	NSUInteger glyphIndex = 0;
	NSUInteger glyphLength = [layoutManager glyphRangeForTextContainer:textContainer].length;
  float lineY;
  
  // are there any lines at all?
  if (glyphLength == 0) {
    NSRect extraFragmentRect = [layoutManager extraLineFragmentRect];
    if (NSHeight(extraFragmentRect) > 0.01 && NSMinY(extraFragmentRect) < NSMaxY(targetRect)) {
      [[DuxLineNumberString stringForNumber:1] drawAtY:NSMinY(extraFragmentRect)];
    }
    return;
  }
  
  // now we calculate the actual line positions  
  // figure out what line is the first one within targetRect
  characterIndex = [layoutManager characterIndexForPoint:targetRect.origin inTextContainer:textContainer fractionOfDistanceBetweenInsertionPoints:NULL];
  lineIndex = 1;
  while (lineIndex < 99999) {
    if (lineCharacterIndexes[lineIndex] >= characterIndex) {
      lineIndex--;
      break;
    }
    
    lineIndex++;
  }
  
  // draw the line numbers
	while (lineIndex < 99999) {
    if (lineCharacterIndexes[lineIndex] == NSNotFound)
      break;
    
    // find the glyph index forthe line
    glyphIndex = [layoutManager glyphIndexForCharacterAtIndex:lineCharacterIndexes[lineIndex]];
		if (glyphIndex >= glyphLength)
			break;
		
		// draw the line
		lineY = [layoutManager lineFragmentRectForGlyphAtIndex:glyphIndex effectiveRange:NULL].origin.y;
    [[DuxLineNumberString stringForNumber:lineIndex + 1] drawAtY:lineY];
		
    // are we done?
    if (lineY > NSMaxY(targetRect)) {
      break;
    }
    
		// move on
		lineIndex++;
	}
  
  // draw "extra" line fragment rect
  NSRect extraFragmentRect = [layoutManager extraLineFragmentRect];
  if (NSHeight(extraFragmentRect) > 0.01 && NSMinY(extraFragmentRect) < NSMaxY(targetRect)) {
    [[DuxLineNumberString stringForNumber:lineIndex + 1] drawAtY:NSMinY(extraFragmentRect)];
  }
}

- (void)editorFontDidChange:(NSNotification *)notif
{
  dispatch_async(dispatch_get_main_queue(), ^{
    NSRange range = NSMakeRange(0, self.textStorage.length);
    [self.textStorage setAttributes:[NSDictionary dictionary] range:range];
    [self.highlighter updateHighlightingForStorage:self.textStorage range:range];
  });
}

- (void)editorTabWidthDidChange:(NSNotification *)notif
{
  dispatch_async(dispatch_get_main_queue(), ^{
    NSRange range = NSMakeRange(0, self.textStorage.length);
    [self.textStorage setAttributes:[NSDictionary dictionary] range:range];
    [self.highlighter updateHighlightingForStorage:self.textStorage range:range];
  });
}

- (void)showLineNumbersDidChange:(NSNotification *)notif
{
  self.showLineNumbers = [DuxPreferences showLineNumbers];
  [(DuxTextContainer *)self.textContainer setLeftGutterWidth:self.showLineNumbers ? 34 : 0];
  
  [self.layoutManager invalidateLayoutForCharacterRange:NSMakeRange(0, self.string.length) actualCharacterRange:NULL];
	
  [self setNeedsDisplay:YES];
}

- (void)showPageGuideDidChange:(NSNotification *)notif
{
  self.showPageGuide = [DuxPreferences showPageGuide];
  
  [self setNeedsDisplay:YES];
}

- (void)showOtherInstancesOfSelectedSymbolDidChange:(NSNotification *)notif
{
	[self updateHighlightedElements];
}

- (void)pageGuidePositionDidChange:(NSNotification *)notif
{
  self.pageGuidePosition = [DuxPreferences pageGuidePosition];
  
  [self setNeedsDisplay:YES];
}

- (void)textContainerSizeDidChange:(NSNotification *)notif
{
  [self setNeedsDisplay:YES];
}

- (NSUndoManager *)undoManager
{
  return self.window.undoManager;
}

- (BOOL)becomeFirstResponder
{
  BOOL accept = [super becomeFirstResponder];

  if (accept) {
    self.backgroundColor = [NSColor duxEditorColor];
  }
  
  return accept;
}

- (BOOL)resignFirstResponder
{
  BOOL accept = [super resignFirstResponder];
  
  if (accept) {
    self.backgroundColor = [NSColor duxBackgroundEditorColor];
  }
  
  return accept;
}

@end
