//
//  KDiffVView.m
//  Ketchup
//
//  Created by Abhi Beckert on 27/06/2013.
//  Copyright (c) 2013 Abhi Beckert. All rights reserved.
//

#import "KDiffView.h"
#import "KChange.h"
#import "DuxSyntaxHighlighter.h"

// number of unchanged lines to show before and after each change
#define UNCHANGED_LINES_COUNT 10

@interface KDiffView ()

@property DuxSyntaxHighlighter *highlighter;
@property NSArray *changeRecords;
@property NSDictionary *changeRecordsByLayerName;

@end

@implementation KDiffView

- (id)initWithFrame:(NSRect)frameRect
{
  if (!(self = [super initWithFrame:frameRect]))
    return nil;
  
  self.wantsLayer = YES;
  self.layer.delegate = self;
  self.layer.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  
  self.highlighter = [[DuxSyntaxHighlighter alloc] init];
  
  return self;
}

- (void)setOperation:(KDiffOperation *)operation
{
  _operation = operation;
  
  // grab contents
  NSString *oldContentsString = operation.oldFileContents;
  DuxStringLineEnumerator *oldLineEnumerator = [oldContentsString lineEnumeratorForLinesInRange:NSMakeRange(0, oldContentsString.length)];
  NSString *newContentsString = operation.newFileContents;
  DuxStringLineEnumerator *newLineEnumerator = [newContentsString lineEnumeratorForLinesInRange:NSMakeRange(0, newContentsString.length)];
  
  // apply syntax highlighting
  DuxLanguage *chosenLanguage = [DuxPlainTextLanguage sharedInstance];
  for (Class language in [DuxLanguage registeredLanguages]) {
    if (![language isDefaultLanguageForURL:operation.url textContents:newContentsString])
      continue;

    chosenLanguage = [language sharedInstance];
    break;
  }
  NSTextStorage *oldContents = [[NSTextStorage alloc] initWithString:oldContentsString attributes:self.highlighter.baseAttributes];
  NSTextStorage *newContents = [[NSTextStorage alloc] initWithString:newContentsString attributes:self.highlighter.baseAttributes];
  [self.highlighter setBaseLanguage:chosenLanguage forTextStorage:oldContents];
  [self.highlighter setBaseLanguage:chosenLanguage forTextStorage:newContents];
  
  // process changes
  NSMutableArray *changeRecords = @[].mutableCopy;
  NSMutableDictionary *changeRecordsByLayerName = @{}.mutableCopy;
  NSMutableArray *unchangedPreviousLines = @[].mutableCopy;
  NSMutableArray *unchangedFollowingLines = @[].mutableCopy;
  NSInteger oldContentsLineNumber = 1;
  NSInteger newContentsLineNumber = 1;
  CGFloat y = 0;
  NSInteger changeIndex;
  NSUInteger changeCount = operation.changes.count;
  for (changeIndex = 0; changeIndex < changeCount; changeIndex++) {
    KChange *change = [operation.changes objectAtIndex:changeIndex];
    KChange *nextChange = changeIndex < (changeCount - 1) ? [operation.changes objectAtIndex:changeIndex + 1] : nil;
    
    NSRange oldContentsRange;
    NSRange newContentsRange;
    
    if (change.oldLineCount == 0) {
      oldContentsRange = NSMakeRange(0, 0);
    } else {
      while (oldContentsLineNumber <= change.oldLineLocation) {
        NSValue *lineRangeObject = [oldLineEnumerator nextObject];
        NSRange lineRange = lineRangeObject.rangeValue;
        
        oldContentsRange = lineRange;
        oldContentsLineNumber++;
      }
      while (oldContentsLineNumber < (change.oldLineLocation + change.oldLineCount)) {
        NSValue *lineRangeObject = [oldLineEnumerator nextObject];
        NSRange lineRange = lineRangeObject.rangeValue;
        
        oldContentsRange.length = NSMaxRange(lineRange) - oldContentsRange.location;
        oldContentsLineNumber++;
      }
    }
    
    if (change.newLineCount == 0) {
      newContentsRange = NSMakeRange(0, 0);
      
      while (newContentsLineNumber < change.newLineLocation) {
        NSValue *lineRangeObject = [newLineEnumerator nextObject];
        NSRange lineRange = lineRangeObject.rangeValue;
        
        [unchangedPreviousLines addObject:[newContents attributedSubstringFromRange:lineRange]];
        if (unchangedPreviousLines.count > UNCHANGED_LINES_COUNT + 1) {
          [unchangedPreviousLines removeObjectAtIndex:0];
        }
        
        newContentsLineNumber++;
      }
    } else {
      while (newContentsLineNumber <= change.newLineLocation) {
        NSValue *lineRangeObject = [newLineEnumerator nextObject];
        NSRange lineRange = lineRangeObject.rangeValue;
        
        if (newContentsLineNumber != change.newLineLocation) {
          [unchangedPreviousLines addObject:[newContents attributedSubstringFromRange:lineRange]];
          if (unchangedPreviousLines.count > UNCHANGED_LINES_COUNT + 1) {
            [unchangedPreviousLines removeObjectAtIndex:0];
          }
        }
        
        newContentsRange = lineRange;
        newContentsLineNumber++;
      }
      while (newContentsLineNumber < (change.newLineLocation + change.newLineCount)) {
        NSValue *lineRangeObject = [newLineEnumerator nextObject];
        NSRange lineRange = lineRangeObject.rangeValue;
        
        newContentsRange.length = NSMaxRange(lineRange) - newContentsRange.location;
        newContentsLineNumber++;
      }
    }
    while (unchangedFollowingLines.count <= UNCHANGED_LINES_COUNT) {
      NSValue *lineRangeObject = [newLineEnumerator nextObject];
      if (!lineRangeObject)
        break;
      NSRange lineRange = lineRangeObject.rangeValue;
      
      [unchangedFollowingLines addObject:[newContents attributedSubstringFromRange:lineRange]];
      
      newContentsLineNumber++;
      if (nextChange && newContentsLineNumber == nextChange.newLineLocation)
        break;
    }
    if (unchangedPreviousLines.count > UNCHANGED_LINES_COUNT) {
      NSAttributedString *secondLine = unchangedPreviousLines[2];
      NSString *whitespace = @"";
      if (secondLine.length > 0) {
        NSUInteger nonWhitespaceIndex = [secondLine.string rangeOfCharacterFromSet:[[NSCharacterSet whitespaceCharacterSet] invertedSet]].location;
        if (nonWhitespaceIndex == NSNotFound)
          whitespace = secondLine.string;
        else
          whitespace = [secondLine.string substringToIndex:nonWhitespaceIndex];
      }
      [unchangedPreviousLines replaceObjectAtIndex:0 withObject:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@• • •", whitespace] attributes:self.highlighter.baseAttributes]];
    }
    if (unchangedFollowingLines.count > UNCHANGED_LINES_COUNT) {
      NSAttributedString *secondLastLine = unchangedFollowingLines[UNCHANGED_LINES_COUNT - 1];
      NSString *whitespace = @"";
      if (secondLastLine.length > 0) {
        NSUInteger nonWhitespaceIndex = [secondLastLine.string rangeOfCharacterFromSet:[[NSCharacterSet whitespaceCharacterSet] invertedSet]].location;
        if (nonWhitespaceIndex == NSNotFound)
          whitespace = secondLastLine.string;
        else
          whitespace = [secondLastLine.string substringToIndex:nonWhitespaceIndex];
      }
      [unchangedFollowingLines replaceObjectAtIndex:UNCHANGED_LINES_COUNT withObject:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@• • •", whitespace] attributes:self.highlighter.baseAttributes]];
    }
    
    NSMutableAttributedString *unchangedPreviousContents = [[NSMutableAttributedString alloc] init];
    NSAttributedString *newlineString = [[NSAttributedString alloc] initWithString:@"\n" attributes:self.highlighter.baseAttributes];
    for (NSAttributedString *lineString in unchangedPreviousLines) {
      if (unchangedPreviousContents.length > 0)
        [unchangedPreviousContents appendAttributedString:newlineString];
      [unchangedPreviousContents appendAttributedString:lineString];
    }
    NSMutableAttributedString *unchangedFollowingContents = [[NSMutableAttributedString alloc] init];
    for (NSAttributedString *lineString in unchangedFollowingLines) {
      if (unchangedFollowingContents.length > 0)
        [unchangedFollowingContents appendAttributedString:newlineString];
      [unchangedFollowingContents appendAttributedString:lineString];
    }
    
    CALayer *oldContentsLayer = [[CALayer alloc] init];
    CALayer *newContentsLayer = [[CALayer alloc] init];
    CALayer *unchangedPreviousContentsLayer = [[CALayer alloc] init];
    CALayer *unchangedFollowingContentsLayer = [[CALayer alloc] init];
    NSDictionary *changeRecord = @{@"change": change,
                                   @"unchangedPreviousContentsLayer": unchangedPreviousContentsLayer,
                                   @"oldContentsLayer": oldContentsLayer,
                                   @"newContentsLayer": newContentsLayer,
                                   @"unchangedFollowingContentsLayer": unchangedFollowingContentsLayer,
                                   @"unchangedPreviousContents": unchangedPreviousContents,
                                   @"unchangedFollowingContents": unchangedFollowingContents,
                                   @"oldContents": [oldContents attributedSubstringFromRange:oldContentsRange],
                                   @"newContents": [newContents attributedSubstringFromRange:newContentsRange]};
    [changeRecords addObject:changeRecord];
    
    CGFloat height = [self layerHeightForAttributedString:changeRecord[@"unchangedPreviousContents"] forWidth:self.frame.size.width];
    unchangedPreviousContentsLayer.frame = CGRectMake(0, 0, self.frame.size.width, height);
    unchangedPreviousContentsLayer.delegate = self;
    unchangedPreviousContentsLayer.needsDisplayOnBoundsChange = YES;
    unchangedPreviousContentsLayer.transform = CATransform3DMakeScale(1.0f, -1.0f, 1.0f);
    unchangedPreviousContentsLayer.name = [NSString stringWithFormat:@"change-%li.unchangedPreviousContents", (long)changeIndex];
    unchangedPreviousContentsLayer.backgroundColor = CGColorCreateGenericGray(1.0, 1.0);
    unchangedPreviousContentsLayer.opacity = 0.6;
    [unchangedPreviousContentsLayer setNeedsDisplay];
    [self.layer addSublayer:unchangedPreviousContentsLayer];
    changeRecordsByLayerName[unchangedPreviousContentsLayer.name] = changeRecord;
    y += unchangedPreviousContentsLayer.frame.size.height;
    
    height = [self layerHeightForAttributedString:changeRecord[@"oldContents"] forWidth:self.frame.size.width];
    oldContentsLayer.frame = CGRectMake(0, 0, self.frame.size.width, height);
    oldContentsLayer.delegate = self;
    oldContentsLayer.needsDisplayOnBoundsChange = YES;
    oldContentsLayer.transform = CATransform3DMakeScale(1.0f, -1.0f, 1.0f);
    oldContentsLayer.name = [NSString stringWithFormat:@"change-%li.oldContents", (long)changeIndex];
    oldContentsLayer.backgroundColor = CGColorCreateGenericRGB(1.0, 0.9, 0.9, 1.0);
    [oldContentsLayer setNeedsDisplay];
    [self.layer addSublayer:oldContentsLayer];
    changeRecordsByLayerName[oldContentsLayer.name] = changeRecord;
    y += oldContentsLayer.frame.size.height;
    
    height = [self layerHeightForAttributedString:changeRecord[@"newContents"] forWidth:self.frame.size.width];
    newContentsLayer.frame = CGRectMake(0, 0, self.frame.size.width, height);
    newContentsLayer.delegate = self;
    newContentsLayer.needsDisplayOnBoundsChange = YES;
    newContentsLayer.transform = CATransform3DMakeScale(1.0f, -1.0f, 1.0f);
    newContentsLayer.name = [NSString stringWithFormat:@"change-%li.newContents", (long)changeIndex];
    newContentsLayer.backgroundColor = CGColorCreateGenericRGB(0.9, 1.0, 0.9, 1.0);
    [self.layer addSublayer:newContentsLayer];
    [newContentsLayer setNeedsDisplay];
    changeRecordsByLayerName[newContentsLayer.name] = changeRecord;
    y += newContentsLayer.frame.size.height;
    
    height = [self layerHeightForAttributedString:changeRecord[@"unchangedFollowingContents"] forWidth:self.frame.size.width];
    unchangedFollowingContentsLayer.frame = CGRectMake(0, 0, self.frame.size.width, height);
    unchangedFollowingContentsLayer.delegate = self;
    unchangedFollowingContentsLayer.needsDisplayOnBoundsChange = YES;
    unchangedFollowingContentsLayer.transform = CATransform3DMakeScale(1.0f, -1.0f, 1.0f);
    unchangedFollowingContentsLayer.name = [NSString stringWithFormat:@"change-%li.unchangedFollowingContents", (long)changeIndex];
    unchangedFollowingContentsLayer.backgroundColor = CGColorCreateGenericGray(1.0, 1.0);
    unchangedFollowingContentsLayer.opacity = 0.6;
    [unchangedFollowingContentsLayer setNeedsDisplay];
    [self.layer addSublayer:unchangedFollowingContentsLayer];
    changeRecordsByLayerName[unchangedFollowingContentsLayer.name] = changeRecord;
    y += unchangedFollowingContentsLayer.frame.size.height;
    
    unchangedPreviousLines = @[].mutableCopy;
    unchangedFollowingLines = @[].mutableCopy;
  }
  
  self.changeRecords = changeRecords.copy;
  self.changeRecordsByLayerName = changeRecordsByLayerName.copy;
  
  [self setFrame:NSMakeRect(0, 0, self.frame.size.width, y)];
  
  [self layoutSublayersOfLayer:self.layer];
}

- (BOOL)isFlipped
{
  return YES;
}

- (BOOL)layer:(CALayer *)layer shouldInheritContentsScale:(CGFloat)newScale fromWindow:(NSWindow *)window
{
  return YES;
}

- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx
{
  if (!layer.name)
    return;
  
  NSDictionary *changeRecord = self.changeRecordsByLayerName[layer.name];
  if (changeRecord) {
    [self drawChangeRecord:changeRecord withLayer:layer inContext:ctx];
  }
}

- (void)drawChangeRecord:(NSDictionary *)changeRecord withLayer:(CALayer *)layer inContext:(CGContextRef)ctx
{
  // Initialize a graphics context and set the text matrix to a known value.
  CGContextSetTextMatrix(ctx, CGAffineTransformIdentity);
  NSString *dataKey = [layer.name componentsSeparatedByString:@"."][1];
  
  if ([changeRecord[dataKey] length] == 0)
    return;
  
  // Initialize a rectangular path.
  CGMutablePathRef path = CGPathCreateMutable();
  CGRect bounds = CGRectMake(10.0, -22, layer.frame.size.width - 20.0, layer.frame.size.height + 20);
  CGPathAddRect(path, NULL, bounds);
  
  // Initialize an attributed string.
  NSAttributedString *attrString = changeRecord[dataKey];
  
  // Create the framesetter with the attributed string.
  CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)(attrString));
  CGSize framesetterSize = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRangeMake(0, 0), NULL, CGSizeMake(bounds.size.width, CGFLOAT_MAX), NULL);
  
  // Create the frame and draw it into the graphics context
  CTFrameRef frame = CTFramesetterCreateFrame(framesetter,
                                              CFRangeMake(0, 0), path, NULL);
  CFRelease(framesetter);
  CGContextSetFillColorWithColor(ctx, layer.backgroundColor);
  CGContextFillRect(ctx, NSMakeRect(bounds.origin.x, bounds.origin.y + bounds.size.height - framesetterSize.height, bounds.size.width, framesetterSize.height));
  CTFrameDraw(frame, ctx);
  
  CFRelease(frame);
  
  // draw a top/bottom border
  BOOL topLine = NO;
  BOOL bottomLine = NO;
  if ([dataKey isEqualToString:@"oldContents"]) {
    topLine = YES;
    if ([changeRecord[@"change"] newLineCount] == 0)
      bottomLine = YES;
  } else if ([dataKey isEqualToString:@"newContents"]) {
    bottomLine = YES;
    if ([changeRecord[@"change"] oldLineCount] == 0)
      topLine = YES;
  }
  
  CGColorRef strokeColor = CGColorCreateGenericRGB(0, 0, 0, 0.5);
  CGContextSetStrokeColorWithColor(ctx, strokeColor);
  CGContextSetLineWidth(ctx, 0.5);
  if (topLine) {
    CGContextMoveToPoint(ctx, 0, layer.frame.size.height - 0.25);
    CGContextAddLineToPoint(ctx, layer.frame.size.width, layer.frame.size.height - 0.25);
    CGContextStrokePath(ctx);
  }
  if (bottomLine) {
    CGContextMoveToPoint(ctx, 0, 0.25);
    CGContextAddLineToPoint(ctx, layer.frame.size.width, 0.25);
    CGContextStrokePath(ctx);
  }
  CFRelease(strokeColor);
}

- (CGFloat)layerHeightForAttributedString:(NSAttributedString *)attrString forWidth:(CGFloat)inWidth
{
  // zero length string has 0 height
  if (attrString.length == 0)
    return 0;
  
  // if last char is a newline... suffix with a " " character, or else we'll return a value without it
  NSCharacterSet *newlineCharacters = [NSCharacterSet newlineCharacterSet];
  if ([newlineCharacters characterIsMember:[attrString.string characterAtIndex:attrString.length - 1]]) {
    NSMutableAttributedString *mutableAttrString = attrString.mutableCopy;
    [mutableAttrString appendAttributedString:[[NSAttributedString alloc] initWithString:@" " attributes:self.highlighter.baseAttributes]];
    attrString = mutableAttrString.copy;
  }
  
  
  CGFloat H = 0;
  
  // Create the framesetter with the attributed string.
  CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)( attrString));
  
  CGRect box = CGRectMake(0,0, inWidth, CGFLOAT_MAX);
  
  CFIndex startIndex = 0;
  
  CGMutablePathRef path = CGPathCreateMutable();
  CGPathAddRect(path, NULL, box);
  
  // Create a frame for this column and draw it.
  CTFrameRef frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(startIndex, 0), path, NULL);
  
  // Start the next frame at the first character not visible in this frame.
  //CFRange frameRange = CTFrameGetVisibleStringRange(frame);
  //startIndex += frameRange.length;
  
  CFArrayRef lineArray = CTFrameGetLines(frame);
  CFIndex j = 0, lineCount = CFArrayGetCount(lineArray);
  CGFloat h, ascent, descent, leading;
  
  for (j=0; j < lineCount; j++)
  {
    CTLineRef currentLine = (CTLineRef)CFArrayGetValueAtIndex(lineArray, j);
    CTLineGetTypographicBounds(currentLine, &ascent, &descent, &leading);
    h = ascent + descent + leading;
    H+=h;
  }
  
  CFRelease(frame);
  CFRelease(path);
  CFRelease(framesetter);
  
  
  return ceil(H) + 4;
}

- (void)layoutSublayersOfLayer:(CALayer *)layer
{
  if (layer != self.layer)
    return;
  
  // change layers
  CGFloat y = 0;
  for (NSDictionary *changeRecord in self.changeRecords) {
    
    // unchanged previous
    CGRect expectedFrame = CGRectMake(0, y, layer.bounds.size.width, [changeRecord[@"unchangedPreviousContentsLayer"] frame].size.height);
    expectedFrame.origin.y = y;
    if (!CGRectEqualToRect([changeRecord[@"unchangedPreviousContentsLayer"] frame], expectedFrame)) {
      [changeRecord[@"unchangedPreviousContentsLayer"] setFrame:expectedFrame];
    }
    y = expectedFrame.origin.y + expectedFrame.size.height;
    
    // old contents
    expectedFrame = CGRectMake(0, y, layer.bounds.size.width, [changeRecord[@"oldContentsLayer"] frame].size.height);
    expectedFrame.origin.y = y;
    if (!CGRectEqualToRect([changeRecord[@"oldContentsLayer"] frame], expectedFrame)) {
      [changeRecord[@"oldContentsLayer"] setFrame:expectedFrame];
    }
    y = expectedFrame.origin.y + expectedFrame.size.height;
    
    // new contents
    expectedFrame = CGRectMake(0, y, layer.bounds.size.width, [changeRecord[@"newContentsLayer"] frame].size.height);
    expectedFrame.origin.y = y;
    if (!CGRectEqualToRect([changeRecord[@"newContentsLayer"] frame], expectedFrame)) {
      [changeRecord[@"newContentsLayer"] setFrame:expectedFrame];
    }
    y = expectedFrame.origin.y + expectedFrame.size.height;
    
    // unchanged following
    expectedFrame = CGRectMake(0, y, layer.bounds.size.width, [changeRecord[@"unchangedFollowingContentsLayer"] frame].size.height);
    expectedFrame.origin.y = y;
    if (!CGRectEqualToRect([changeRecord[@"unchangedFollowingContentsLayer"] frame], expectedFrame)) {
      [changeRecord[@"unchangedFollowingContentsLayer"] setFrame:expectedFrame];
    }
    y = expectedFrame.origin.y + expectedFrame.size.height;
  }
}

@end
