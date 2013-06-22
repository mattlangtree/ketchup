//
//  KSVNDiffOperation.h
//  Ketchup
//
//  Created by Abhi Beckert on 22/06/2013.
//  Copyright (c) 2013 Abhi Beckert. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KDiffOperation.h"

@interface KSVNDiffOperation : KDiffOperation
{
  NSArray *_changes;
}

@end
