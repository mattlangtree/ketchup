//
//  KDiffOperation.m
//  Ketchup
//
//  Created by Abhi Beckert on 22/06/2013.
//  Copyright (c) 2013 Abhi Beckert. All rights reserved.
//

#import "KDiffOperation.h"

@interface KDiffOperation ()

@property NSURL *url;

@end

@implementation KDiffOperation

+ (instancetype)diffOperationWithFileUrl:(NSURL *)url
{
  return [[[self class] alloc] initWithFileUrl:url];
}

- (instancetype)initWithFileUrl:(NSURL *)url
{
  if (!(self = [super init]))
    return nil;
  
  self.url = url;
  
  return self;
}

- (NSArray *)changes
{
  [NSException raise:@"Not Yet Implemented" format:@"A subclass must implement %s", __PRETTY_FUNCTION__];
  
  return nil;
}

- (NSString *)newFileContents
{
  NSString *textContent = [NSString stringWithContentsOfURL:self.url usedEncoding:NULL error:NULL];
  if (!textContent) {
    NSLog(@"cannot read file %@", self.url);
    return @"";
  }
  
  return textContent;
}

- (NSString *)oldFileContents
{
  [NSException raise:@"Not Yet Implemented" format:@"A subclass must implement %s", __PRETTY_FUNCTION__];
  return @"";
}

@end
