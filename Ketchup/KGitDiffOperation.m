//
//  KGitDiffOperation.m
//  Ketchup
//
//  Created by Matt Langtree on 24/06/2013.
//  Copyright (c) 2013 Abhi Beckert. All rights reserved.
//

#import "KGitDiffOperation.h"

@implementation KGitDiffOperation

- (instancetype)initWithFileUrl:(NSURL *)url
{
    if (!(self = [super initWithFileUrl:url]))
        return nil;

    return self;
}

- (NSString *)oldFileContents
{
    return @"not yet implemented";
}

- (NSArray *)changes
{
    return @[];
}


@end
