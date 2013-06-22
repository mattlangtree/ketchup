//
//  KDiffOperation.h
//  Ketchup
//
//  Created by Abhi Beckert on 22/06/2013.
//  Copyright (c) 2013 Abhi Beckert. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KChange.h"

@interface KDiffOperation : NSObject
{
}

+ (instancetype)diffOperationWithFileUrl:(NSURL *)url;
- (instancetype)initWithFileUrl:(NSURL *)url;

@property (readonly) NSURL *url;
@property (readonly) NSArray *changes;

@end
