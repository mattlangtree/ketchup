//
//  KDocumentController.h
//  Ketchup
//
//  Created by Abhi Beckert on 2013-6-6.
//  Copyright (c) 2013 Abhi Beckert. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class KWelcomeWindowController;

@interface KDocumentController : NSDocumentController <NSApplicationDelegate>

@property (strong) KWelcomeWindowController *welcomeController;

@end
