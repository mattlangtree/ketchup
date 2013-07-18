//
//  KChange.m
//  Ketchup
//
//  Created by Abhi Beckert on 22/06/2013.
//  Copyright (c) 2013 Abhi Beckert. All rights reserved.
//

#import "KChange.h"

@implementation KChange

- (NSString *)description
{
  return [NSString stringWithFormat:@"<%@: {{%lu, %lu}, {%lu, %lu}}>", NSStringFromClass([self class]), self.newLineLocation, self.newLineCount, self.oldLineLocation, self.oldLineCount];
}

@end
