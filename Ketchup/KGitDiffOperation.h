//
//  KGitDiffOperation.h
//  Ketchup
//
//  Created by Matt Langtree on 24/06/2013.
//  Copyright (c) 2013 Abhi Beckert. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KDiffOperation.h"

@interface KGitDiffOperation : KDiffOperation
{
    NSArray *_changes;
    NSString *_oldFileContents;
}

@property (strong) NSURL *workingDirectory;

- (instancetype)initWithFileUrl:(NSURL *)url workingDirectoryURL:(NSURL *)workingDirectory;
+ (instancetype)diffOperationWithFileUrl:(NSURL *)url workingDirectoryURL:(NSURL *)workingDirectory;
@end
