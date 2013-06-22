//
//  KChange.h
//  Ketchup
//
//  Created by Abhi Beckert on 22/06/2013.
//  Copyright (c) 2013 Abhi Beckert. All rights reserved.
//

/**
 * represents a single change in a file and is used for drawing the diff view.
 */

#import <Foundation/Foundation.h>

@interface KChange : NSObject

@property NSString *leftString;
@property NSArray *leftHighlightedRanges;

@property NSString *rightString;
@property NSArray *rightHighlightedRanges;



@end
