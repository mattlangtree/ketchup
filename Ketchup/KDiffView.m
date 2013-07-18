//
//  KDiffVView.m
//  Ketchup
//
//  Created by Abhi Beckert on 27/06/2013.
//  Copyright (c) 2013 Abhi Beckert. All rights reserved.
//

#import "KDiffView.h"
#import "KChange.h"

@interface KDiffView ()

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
  
  return self;
}

- (void)setOperation:(KDiffOperation *)operation
{
  _operation = operation;
  
  NSString *oldContents = operation.oldFileContents;
  DuxStringLineEnumerator *oldLineEnumerator = [oldContents lineEnumeratorForLinesInRange:NSMakeRange(0, oldContents.length)];
  NSString *newContents = operation.newFileContents;
  DuxStringLineEnumerator *newLineEnumerator = [newContents lineEnumeratorForLinesInRange:NSMakeRange(0, newContents.length)];
  
  NSMutableArray *changeRecords = @[].mutableCopy;
  NSMutableDictionary *changeRecordsByLayerName = @{}.mutableCopy;
  NSInteger changeIndex = -1;
  NSInteger oldContentsLineNumber = 1;
  NSInteger newContentsLineNumber = 1;
  for (KChange *change in operation.changes) {
    changeIndex++;
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
    } else {
      while (newContentsLineNumber <= change.newLineLocation) {
        NSValue *lineRangeObject = [newLineEnumerator nextObject];
        NSRange lineRange = lineRangeObject.rangeValue;
        
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
    
    CALayer *layer = [[CALayer alloc] init];
    layer.delegate = self;
    layer.needsDisplayOnBoundsChange = YES;
    layer.transform = CATransform3DMakeScale(1.0f, -1.0f, 1.0f);
    layer.name = [NSString stringWithFormat:@"change-%li", (long)changeIndex];
    [self.layer addSublayer:layer];
    
    NSDictionary *changeRecord = @{@"change": change,
                                   @"layer": layer,
                                   @"oldContents": [oldContents substringWithRange:oldContentsRange],
                                   @"newContents": [newContents substringWithRange:newContentsRange]};
    
    [changeRecords addObject:changeRecord];
    changeRecordsByLayerName[layer.name] = changeRecord;
  }
  self.changeRecords = changeRecords.copy;
  self.changeRecordsByLayerName = changeRecordsByLayerName.copy;
  
  CGFloat height = changeRecords.count * 142; // todo: calculate actual height
  [self setFrame:NSMakeRect(0, 0, self.frame.size.width, height)];
  
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
  CGFloat y = 0;
  
  if ([changeRecord[@"oldContents"] length] != 0) {
    // Initialize a rectangular path.
    CGMutablePathRef path = CGPathCreateMutable();
    CGRect bounds = CGRectMake(10.0, 3.0, layer.frame.size.width - 20.0, layer.frame.size.height - 6.0);
    CGPathAddRect(path, NULL, bounds);
    
    // Initialize an attributed string.
    CFMutableAttributedStringRef attrString = CFAttributedStringCreateMutable(kCFAllocatorDefault, 0);
    CFAttributedStringReplaceString(attrString, CFRangeMake(0, 0), (__bridge CFStringRef)(changeRecord[@"oldContents"]));
    
    // Create the framesetter with the attributed string.
    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString(attrString);
    CGSize framesetterSize = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRangeMake(0, 0), NULL, CGSizeMake(bounds.size.width, CGFLOAT_MAX), NULL);
    CFRelease(attrString);
    
    // Create the frame and draw it into the graphics context
    CTFrameRef frame = CTFramesetterCreateFrame(framesetter,
                                                CFRangeMake(0, 0), path, NULL);
    CFRelease(framesetter);
    CGContextSetRGBFillColor(ctx, 1, 0.9, 0.9, 1);
    CGContextFillRect(ctx, NSMakeRect(bounds.origin.x, bounds.origin.y + bounds.size.height - framesetterSize.height, bounds.size.width, framesetterSize.height));
    CTFrameDraw(frame, ctx);
    CFRelease(frame);
    
    y += framesetterSize.height;
  }
  
  if ([changeRecord[@"newContents"] length] != 0) {
    // Initialize a rectangular path.
    CGMutablePathRef path = CGPathCreateMutable();
    CGRect bounds = CGRectMake(10.0, 3.0, layer.frame.size.width - 20.0, layer.frame.size.height - 6.0 - y);
    CGPathAddRect(path, NULL, bounds);
    
    // Initialize an attributed string.
    CFMutableAttributedStringRef attrString = CFAttributedStringCreateMutable(kCFAllocatorDefault, 0);
    CFAttributedStringReplaceString(attrString, CFRangeMake(0, 0), (__bridge CFStringRef)(changeRecord[@"newContents"]));
    
    // Create the framesetter with the attributed string.
    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString(attrString);
    CGSize framesetterSize = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRangeMake(0, 0), NULL, CGSizeMake(bounds.size.width, CGFLOAT_MAX), NULL);
    CFRelease(attrString);
    
    // Create the frame and draw it into the graphics context
    CTFrameRef frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, NULL);
    CFRelease(framesetter);
    CGContextSetRGBFillColor(ctx, 0.9, 1, 0.9, 1);
    CGContextFillRect(ctx, NSMakeRect(bounds.origin.x, bounds.origin.y + bounds.size.height - framesetterSize.height, bounds.size.width, framesetterSize.height));
    CTFrameDraw(frame, ctx);
    CFRelease(frame);
  }
}

- (void)layoutSublayersOfLayer:(CALayer *)layer
{
  if (layer != self.layer)
    return;
  
  // change layers
  CGFloat y = 0;
  for (NSDictionary *changeRecord in self.changeRecords) {
    CGRect expectedFrame = CGRectMake(0, y, layer.bounds.size.width, 0);
    CGFloat height = 142; // todo: calculate actual string height
    expectedFrame.size.height = height;
    expectedFrame.origin.y = y;
    if (!CGRectEqualToRect([changeRecord[@"layer"] frame], expectedFrame)) {
      [changeRecord[@"layer"] setFrame:expectedFrame];
    }
    
    y = expectedFrame.origin.y + expectedFrame.size.height;
  }
}

@end
