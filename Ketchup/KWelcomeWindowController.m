//
//  KWelcomeWindowController.m
//  Ketchup
//
//  Created by Matt Langtree on 24/06/2013.
//  Copyright (c) 2013 Abhi Beckert. All rights reserved.
//

#import "KWelcomeWindowController.h"
#import "KDocument.h"

@interface KWelcomeWindowController ()

@end

@implementation KWelcomeWindowController

- (id)init
{
    self = [super initWithWindowNibName:@"KWelcomeWindow"];
    if (self) {
      _recentDocuments = [self fetchRecentDocuments];
    }
    
    return self;
}

- (void)windowDidLoad
{
  [super windowDidLoad];
  
  [_filesList setTarget:self];
  [_filesList setDoubleAction:@selector(didDoubleClickItem:)];
}

- (NSArray *)fetchRecentDocuments
{
  NSDocumentController *controller = [NSDocumentController sharedDocumentController];
  return [controller recentDocumentURLs];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
  return [_recentDocuments count];
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
  
  NSTextField *result = [tableView makeViewWithIdentifier:@"RecentDocument" owner:self];
  
  if (result == nil) {
    
    result = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 308, 45)];
    result.editable = NO;
    result.bordered = NO;
    result.identifier = @"RecentDocument";
  }
  
  result.stringValue = [_recentDocuments objectAtIndex:row];
  return result;
}

- (IBAction)didDoubleClickItem:(id)sender
{
  NSLog(@"double click item");
  NSInteger row = [_filesList clickedRow];
  NSURL *url = [_recentDocuments objectAtIndex:row];
  
  NSDocumentController *controller = [NSDocumentController sharedDocumentController];
  [controller openDocumentWithContentsOfURL:url display:YES completionHandler:^(NSDocument *document, BOOL documentWasAlreadyOpen, NSError *error) {
    
    dispatch_async(dispatch_get_main_queue(), ^{
      [self close];
    });
    
  }];
}

@end
