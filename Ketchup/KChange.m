//
//  KChange.m
//  Ketchup
//
//  Created by Abhi Beckert on 22/06/2013.
//  Copyright (c) 2013 Abhi Beckert. All rights reserved.
//

#import "KChange.h"

@implementation KChange

- (id)init
{
  if (!(self = [super init]))
    return nil;
  
  self.leftString = @"";
  self.rightString = @"".mutableCopy;
  self.leftHighlightedRanges = @[];
  self.rightHighlightedRanges = @[];
  
  return self;
}

@end
