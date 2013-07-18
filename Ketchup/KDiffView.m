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
  
  NSMutableArray *changeRecords = @[].mutableCopy;
  NSMutableDictionary *changeRecordsByLayerName = @{}.mutableCopy;
  int changeIndex = -1;
  for (KChange *change in operation.changes) {
    changeIndex++;
    
    CALayer *layer = [[CALayer alloc] init];
    layer.delegate = self;
    layer.needsDisplayOnBoundsChange = YES;
    layer.name = [NSString stringWithFormat:@"change-%i", changeIndex];
    [self.layer addSublayer:layer];
    
    NSDictionary *changeRecord = @{@"change": change,
                                   @"layer": layer};
    
    [changeRecords addObject:changeRecord];
    changeRecordsByLayerName[layer.name] = changeRecord;
  }
  self.changeRecords = changeRecords.copy;
  self.changeRecordsByLayerName = changeRecordsByLayerName.copy;
  
  [self layoutSublayersOfLayer:self.layer];
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
  // fill background with white (opaque background is necessary for subpixel text anti-aliasing)
  CGContextSetGrayFillColor(ctx, 1.0, 1.0);
  CGContextFillRect(ctx, layer.bounds);
  
  // Initialize a graphics context and set the text matrix to a known value.
  CGContextSetTextMatrix(ctx, CGAffineTransformIdentity);
  
  // Initialize a rectangular path.
  CGMutablePathRef path = CGPathCreateMutable();
  CGRect bounds = CGRectMake(10.0, 3.0, layer.frame.size.width - 10.0, layer.frame.size.height - 3.0);
  CGPathAddRect(path, NULL, bounds);
  
  // Initialize an attributed string.
  CFMutableAttributedStringRef attrString = CFAttributedStringCreateMutable(kCFAllocatorDefault, 0);
  CFAttributedStringReplaceString(attrString, CFRangeMake(0, 0), (__bridge CFStringRef)([changeRecord[@"change"] description]));
  
  // Create the framesetter with the attributed string.
  CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString(attrString);
  CFRelease(attrString);
  
  // Create the frame and draw it into the graphics context
  CTFrameRef frame = CTFramesetterCreateFrame(framesetter,
                                              CFRangeMake(0, 0), path, NULL);
  CFRelease(framesetter);
  CTFrameDraw(frame, ctx);
  CFRelease(frame);
}

- (void)layoutSublayersOfLayer:(CALayer *)layer
{
  if (layer != self.layer)
    return;
  
  // change layers
  CGFloat y = self.frame.size.height;
  for (NSDictionary *changeRecord in self.changeRecords) {
    CGRect expectedFrame = CGRectMake(0, y, layer.bounds.size.width, 0);
    CGFloat height = 22; // todo: calculate actual string height
    expectedFrame.size.height = height;
    expectedFrame.origin.y -= height;
    if (!CGRectEqualToRect([changeRecord[@"layer"] frame], expectedFrame)) {
      [changeRecord[@"layer"] setFrame:expectedFrame];
    }
    
    y = expectedFrame.origin.y;
  }
}

@end
