//
//  KHGDocument.m
//  Ketchup
//
//  Created by Matt Langtree on 8/06/13.
//  Copyright (c) 2013 Abhi Beckert. All rights reserved.
//

#import "KHGDocument.h"

@implementation KHGDocument

- (NSString *)syncButtonTitle
{
  return @"Update";
}

- (void)commit
{
  NSLog(@"Commit not implemented for HG yet.");
}

@end
