//
//  KWelcomeWindowController.h
//  Ketchup
//
//  Created by Matt Langtree on 24/06/2013.
//  Copyright (c) 2013 Abhi Beckert. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface KWelcomeWindowController : NSWindowController <NSTableViewDataSource, NSTableViewDelegate>

@property (strong) NSArray *recentDocuments;
@property (strong) IBOutlet NSTableView *filesList;


- (IBAction)didDoubleClickItem:(id)sender;
- (IBAction)openExistingRepository:(id)sender;
@end
