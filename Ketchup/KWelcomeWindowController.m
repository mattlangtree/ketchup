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
  
  NSTableCellView *cellView = [tableView makeViewWithIdentifier:@"RecentDocument" owner:self];

  if (cellView == nil) {
    cellView = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 308, 45)];
    cellView.identifier = @"RecentDocument";
  }

  NSTextField *textField = [[NSTextField alloc] initWithFrame:NSMakeRect(42, 22,308, 20)];
  textField.backgroundColor = [NSColor clearColor];
  textField.font = [NSFont systemFontOfSize:13.f];
  textField.editable = NO;
  textField.bordered = NO;
  [cellView addSubview:textField];

  NSTextField *pathTextField = [[NSTextField alloc] initWithFrame:NSMakeRect(42, 5, 308, 20)];
  pathTextField.backgroundColor = [NSColor clearColor];
  pathTextField.editable = NO;
  pathTextField.bordered = NO;
  pathTextField.font = [NSFont systemFontOfSize:11.f];
  pathTextField.textColor = [NSColor lightGrayColor];
  [cellView addSubview:pathTextField];
  
  NSImageView *imageView = [[NSImageView alloc] initWithFrame:NSMakeRect(4, 7, 32, 32)];
  [cellView addSubview:imageView];

  NSURL *URL = [_recentDocuments objectAtIndex:row];
  textField.stringValue = [URL lastPathComponent];
  pathTextField.stringValue = URL.path;
  imageView.image = [[NSWorkspace sharedWorkspace] iconForFile:URL.path];
  return cellView;
}

- (IBAction)didDoubleClickItem:(id)sender
{
  NSInteger row = [_filesList clickedRow];
  NSURL *url = [_recentDocuments objectAtIndex:row];
  
  NSDocumentController *controller = [NSDocumentController sharedDocumentController];
  [controller openDocumentWithContentsOfURL:url display:YES completionHandler:^(NSDocument *document, BOOL documentWasAlreadyOpen, NSError *error) {
    
    dispatch_async(dispatch_get_main_queue(), ^{
      [self close];
    });
    
  }];
}

- (IBAction)openExistingRepository:(id)sender
{
  [[NSDocumentController sharedDocumentController] openDocument:nil];
}

@end
