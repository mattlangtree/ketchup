//
//  KDocument.m
//  Ketchup
//
//  Created by Abhi Beckert on 2013-6-6.
//  Copyright (c) 2013 Abhi Beckert. All rights reserved.
//

#import "KDocument.h"

@implementation KDocument

@synthesize window = _kwindow; // cannot use _window, because NSDocument already has that ivar

- (id)init
{
    self = [super init];
    if (self) {
    // Add your subclass-specific initialization here.
    }
    return self;
}

- (NSString *)windowNibName
{
  // Override returning the nib file name of the document
  // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
  return @"KDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
  [super windowControllerDidLoadNib:aController];
  
  
  NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 10, 600, 20)];
  label.editable = NO;
  label.bordered = NO;
  label.backgroundColor = [NSColor clearColor];
  label.stringValue = self.fileURL ? [self.fileURL description] : @"(nil)";
  [self.window.contentView addSubview:label];
  
  label = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 30, 600, 20)];
  label.editable = NO;
  label.backgroundColor = [NSColor clearColor];
  label.bordered = NO;
  label.stringValue = NSStringFromClass([self class]);
  [self.window.contentView addSubview:label];
  
  [self.window makeKeyAndOrderFront:self];
}

+ (BOOL)autosavesInPlace
{
    return YES;
}

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)outError
{
  return YES;
}

@end
