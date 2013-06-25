//
//  KWelcomeWindowController.m
//  Ketchup
//
//  Created by Matt Langtree on 24/06/2013.
//  Copyright (c) 2013 Abhi Beckert. All rights reserved.
//

#import "KWelcomeWindowController.h"

@interface KWelcomeWindowController ()

@end

@implementation KWelcomeWindowController

- (id)init
{
    self = [super initWithWindowNibName:@"KWelcomeWindow"];
    if (self) {
        
    }
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    NSLog(@"nib file is loaded");
}

@end
