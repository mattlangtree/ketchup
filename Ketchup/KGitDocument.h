//
//  KGitDocument.h
//  Ketchup
//
//  Created by Abhi Beckert on 2013-6-6.
//  Copyright (c) 2013 Abhi Beckert. All rights reserved.
//

#import "KDocument.h"


@interface KGitDocument : KDocument

@property (nonatomic, strong) NSTextField *currentBranchLabel;
@property (nonatomic, strong) NSTextView *unsyncedcommitsList;

@property (nonatomic, strong) NSString *currentBranchString;
@property (nonatomic, strong) NSArray *unsyncedCommits;

@end
