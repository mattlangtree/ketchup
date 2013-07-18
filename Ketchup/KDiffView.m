//
//  KDiffVView.m
//  Ketchup
//
//  Created by Abhi Beckert on 27/06/2013.
//  Copyright (c) 2013 Abhi Beckert. All rights reserved.
//

#import "KDiffView.h"

@interface KDiffView ()

@property CALayer *pathLayer;

@end

@implementation KDiffView

- (id)initWithFrame:(NSRect)frameRect
{
  if (!(self = [super initWithFrame:frameRect]))
    return nil;
  
  self.wantsLayer = YES;
  self.layer.delegate = self;
  
  self.pathLayer = [[CALayer alloc] init];
  self.pathLayer.delegate = self;
  self.pathLayer.needsDisplayOnBoundsChange = YES;
  [self.layer addSublayer:self.pathLayer];
  
  return self;
}

- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx
{
  if (layer == self.pathLayer) {
    [self drawPathLayer:layer inContext:ctx];
  }
}

- (void)drawPathLayer:(CALayer *)layer inContext:(CGContextRef)ctx
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
  CFAttributedStringReplaceString (attrString, CFRangeMake(0, 0), (__bridge CFStringRef)(self.operation.url.path.stringByAbbreviatingWithTildeInPath));
  
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
  
  // path layer
  CGRect expectedFrame = CGRectMake(0, self.layer.frame.size.height - 22, self.layer.frame.size.width, 22);
  if (!CGRectEqualToRect(expectedFrame, self.pathLayer.frame)) {
    self.pathLayer.frame = expectedFrame;
  }
}

@end
