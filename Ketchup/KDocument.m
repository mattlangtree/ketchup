//
//  KDocument.m
//  Ketchup
//
//  Created by Abhi Beckert on 2013-6-6.
//  Copyright (c) 2013 Abhi Beckert. All rights reserved.
//

#import "KDocument.h"
#import "KDocumentVersionedFile.h"

@interface KDocument()

@property (strong) NSArray *filesWithStatus;

@end

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
  [self.window setFrame:NSMakeRect(0, 0, 900, 600) display:NO];
  [self.window center];
  self.window.minSize = NSMakeSize(400, 400);
  
  CGFloat windowHeight = [self.window.contentView frame].size.height;
  CGFloat sidebarWidth = 250;
  CGFloat contentWidth = [self.window.contentView frame].size.width - sidebarWidth;
  CGFloat commitMessageHeight = 200;
  
  // create window
  [super windowControllerDidLoadNib:aController];
  
  self.window.title = [self.fileURL.path stringByAbbreviatingWithTildeInPath];
  self.window.representedURL = self.fileURL;
  
  // create sidebar views
  self.sidebarView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, sidebarWidth, windowHeight)];
  self.sidebarView.wantsLayer = YES;
  self.sidebarView.layer = [CAGradientLayer layer];
  self.sidebarView.layer.frame = self.sidebarView.bounds;
  ((CAGradientLayer *)self.sidebarView.layer).colors = @[(id)([NSColor colorWithDeviceRed:0.82 green:0.85 blue:0.88 alpha:1.0].CGColor), (id)([NSColor colorWithDeviceRed:0.87 green:0.89 blue:0.91 alpha:1.0].CGColor)];
  
  self.remoteView = [[NSView alloc] initWithFrame:NSMakeRect(0, windowHeight - 75, sidebarWidth, 75)];
  self.remoteView.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
  [self.sidebarView addSubview:self.remoteView];
  
  self.remoteLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 10, 10)];
  self.remoteLabel.backgroundColor = [NSColor clearColor];
  self.remoteLabel.editable = NO;
  self.remoteLabel.bordered = NO;
  self.remoteLabel.font = [NSFont boldSystemFontOfSize:13];
  self.remoteLabel.textColor = [NSColor colorWithDeviceRed:0.44 green:0.49 blue:0.55 alpha:1.0];
  self.remoteLabel.shadow = [[NSShadow alloc] init];
  self.remoteLabel.shadow.shadowOffset = NSMakeSize(0, 1);
  self.remoteLabel.shadow.shadowBlurRadius = 0.25;
  self.remoteLabel.shadow.shadowColor = [NSColor colorWithCalibratedWhite:1.0 alpha:1.0];
  self.remoteLabel.stringValue = @"REMOTE";
  [self.remoteLabel sizeToFit];
  self.remoteLabel.frame = NSMakeRect(10, self.remoteView.frame.size.height - 9 - self.remoteLabel.frame.size.height, self.remoteLabel.frame.size.width, self.remoteLabel.frame.size.height);
  [self.remoteView addSubview:self.remoteLabel];
  
  self.remoteSyncButton = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 10, 10)];
  self.remoteSyncButton.autoresizingMask = NSViewMinXMargin | NSViewMinYMargin;
  self.remoteSyncButton.title = [self syncButtonTitle];
  self.remoteSyncButton.buttonType = NSMomentaryLightButton;
  self.remoteSyncButton.bezelStyle = NSRoundedBezelStyle;
  [self.remoteSyncButton sizeToFit];
  self.remoteSyncButton.frame = NSMakeRect(sidebarWidth - 16 - self.remoteSyncButton.frame.size.width, self.remoteView.frame.size.height - 5 - self.remoteSyncButton.frame.size.height, self.remoteSyncButton.frame.size.width + 6, self.remoteSyncButton.frame.size.height + 1);
  [self.remoteView addSubview:self.remoteSyncButton];
  
  self.remoteStatusIconView = [[NSImageView alloc] initWithFrame:NSMakeRect(13, 17, 16, 16)];
  self.remoteStatusIconView.image = [NSImage imageNamed:@"led-up-to-date"];
  [self.remoteView addSubview:self.remoteStatusIconView];
  
  self.remoteStatusField = [[NSTextField alloc] initWithFrame:NSMakeRect(33, 0, sidebarWidth - 50, 35)];
  self.remoteStatusField.autoresizingMask = NSViewWidthSizable;
  self.remoteStatusField.font = [NSFont systemFontOfSize:13];
  self.remoteStatusField.backgroundColor = [NSColor clearColor];
  self.remoteStatusField.bordered = NO;
  self.remoteStatusField.editable = NO;
  self.remoteStatusField.stringValue = @"Local/Remote are in sync";
  [self.remoteView addSubview:self.remoteStatusField];
  
  self.filesView = [[NSView alloc] initWithFrame:NSMakeRect(0, 200, sidebarWidth, windowHeight - 275)];
  self.filesView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  [self.sidebarView addSubview:self.filesView];
  
  self.filesLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 10, 10)];
  self.filesLabel.backgroundColor = [NSColor clearColor];
  self.filesLabel.autoresizingMask = NSViewMinYMargin;
  self.filesLabel.editable = NO;
  self.filesLabel.bordered = NO;
  self.filesLabel.font = [NSFont boldSystemFontOfSize:13];
  self.filesLabel.textColor = [NSColor colorWithDeviceRed:0.44 green:0.49 blue:0.55 alpha:1.0];
  self.filesLabel.shadow = [[NSShadow alloc] init];
  self.filesLabel.shadow.shadowOffset = NSMakeSize(0, 1);
  self.filesLabel.shadow.shadowBlurRadius = 0.25;
  self.filesLabel.shadow.shadowColor = [NSColor colorWithCalibratedWhite:1.0 alpha:1.0];
  self.filesLabel.stringValue = @"FILES";
  [self.filesLabel sizeToFit];
  self.filesLabel.frame = NSMakeRect(10, self.filesView.frame.size.height - 9 - self.filesLabel.frame.size.height, self.filesLabel.frame.size.width, self.filesLabel.frame.size.height);
  [self.filesView addSubview:self.filesLabel];
  
  self.filesOutlineView = [[NSOutlineView alloc] initWithFrame:NSMakeRect(0, 0, 10, 10)];
  self.filesOutlineView.backgroundColor = [NSColor clearColor];
  self.filesOutlineView.headerView = nil;
  self.filesOutlineView.dataSource = self;
  self.filesOutlineView.delegate = self;
  self.filesOutlineView.rowHeight = 40;
  
  NSTableColumn * column = [[NSTableColumn alloc] initWithIdentifier:@"filename"];
  [column setWidth:sidebarWidth];
  [self.filesOutlineView addTableColumn:column];
  self.filesOutlineView.outlineTableColumn = column;
  
  NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 1, sidebarWidth, self.filesView.frame.size.height - 32)];
  scrollView.documentView = self.filesOutlineView;
  scrollView.hasVerticalScroller = YES;
  scrollView.autoresizesSubviews = YES;
  scrollView.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;
  scrollView.drawsBackground = NO;
  scrollView.borderType = NSNoBorder;
  [self.filesView addSubview:scrollView];
  
  // TODO: this should be a mail.app style gradient if it is possible to scroll down, and completely invisible if you can't scroll down. the same thing should also be at the top of the outline view
  NSBox *scrollViewBottomBorder = [[NSBox alloc] initWithFrame:NSMakeRect(0, 0, sidebarWidth, 1)];
  scrollViewBottomBorder.autoresizingMask = NSViewWidthSizable;
  scrollViewBottomBorder.boxType = NSBoxSeparator;
  scrollViewBottomBorder.alphaValue = 0.25;
  [self.filesView addSubview:scrollViewBottomBorder];
  
  
  self.commitView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, sidebarWidth, commitMessageHeight)];
  self.commitView.autoresizingMask = NSViewWidthSizable;
  [self.sidebarView addSubview:self.commitView];
  
  self.commitLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 10, 10)];
  self.commitLabel.font = [NSFont boldSystemFontOfSize:13];
  self.commitLabel.textColor = [NSColor colorWithDeviceRed:0.44 green:0.49 blue:0.55 alpha:1.0];
  self.commitLabel.shadow = [[NSShadow alloc] init];
  self.commitLabel.shadow.shadowOffset = NSMakeSize(0, 1);
  self.commitLabel.shadow.shadowBlurRadius = 0.25;
  self.commitLabel.shadow.shadowColor = [NSColor colorWithCalibratedWhite:1.0 alpha:1.0];
  self.commitLabel.stringValue = @"COMMIT";
  self.commitLabel.editable = NO;
  [self.commitLabel sizeToFit];
  self.commitLabel.backgroundColor = [NSColor clearColor];
  self.commitLabel.bordered = NO;
  self.commitLabel.frame = NSMakeRect(10, commitMessageHeight - 9 - self.commitLabel.frame.size.height, self.commitLabel.frame.size.width, self.commitLabel.frame.size.height);
  
  [self.commitView addSubview:self.commitLabel];
  
  self.commitTextView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 10, 10)];
  self.commitTextView.autoresizingMask = NSViewWidthSizable;
  self.commitTextView.font = [NSFont systemFontOfSize:13];
  self.commitTextView.textColor = [NSColor blackColor];
  
  NSScrollView *commitScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(10, 40, sidebarWidth-20, commitMessageHeight-80)];
  commitScrollView.autoresizingMask = NSViewWidthSizable;
  commitScrollView.backgroundColor = [NSColor redColor];
  commitScrollView.documentView = self.commitTextView;
  commitScrollView.hasVerticalScroller = YES;
  commitScrollView.autoresizesSubviews = YES;
  [self.commitView addSubview:commitScrollView];
  self.commitTextView.frame = NSMakeRect(10, 10, commitScrollView.frame.size.width, commitScrollView.frame.size.height);
  
  self.commitAutoSyncButton = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 10, 10)];
  self.commitAutoSyncButton.title = [self autoSyncButtonTitle];
  self.commitAutoSyncButton.buttonType = NSSwitchButton;
  self.commitAutoSyncButton.bezelStyle = NSRoundedBezelStyle;
  [self.commitAutoSyncButton sizeToFit];
  self.commitAutoSyncButton.frame = NSMakeRect(10, 10, sidebarWidth - 20, 20);
  [self.commitView addSubview:self.commitAutoSyncButton];
  
  self.commitButton = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 10, 10)];
  self.commitButton.autoresizingMask = NSViewMinXMargin;
  self.commitButton.title = @"Commit";
  self.commitButton.buttonType = NSMomentaryLightButton;
  self.commitButton.bezelStyle = NSRoundedBezelStyle;
  [self.commitButton sizeToFit];
  self.commitButton.frame = NSMakeRect(sidebarWidth - 16 - self.commitButton.frame.size.width, 4, self.commitButton.frame.size.width + 6, self.commitButton.frame.size.height + 1);
  [self.commitButton setAction:@selector(commit)];
  [self.commitButton setTarget:nil];
  [self.commitView addSubview:self.commitButton];
  
  // create content views
  self.contentView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, contentWidth, windowHeight)];
  
  // create split view
  self.windowSplitView = [[NSSplitView alloc] initWithFrame:[self.window.contentView bounds]];
  self.windowSplitView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  [self.windowSplitView setVertical:YES];
  self.windowSplitView.delegate = self;
  [self.windowSplitView addSubview:self.sidebarView];
  [self.windowSplitView addSubview:self.contentView];
  [self.windowSplitView setPosition:sidebarWidth ofDividerAtIndex:0];
  [self.window.contentView addSubview:self.windowSplitView];
  
  [self.window makeFirstResponder:self.filesOutlineView];
  [self.window makeKeyAndOrderFront:self];
  
  // load files
  self.filesWithStatus = [self fetchFilesWithStatus];
  [self.filesOutlineView reloadData];
}

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)outError
{
  return YES;
}

- (BOOL)splitView:(NSSplitView *)splitView shouldAdjustSizeOfSubview:(NSView *)view
{
  if (view == self.sidebarView)
    return NO;
  
  return YES;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex
{
  return MAX(150, proposedMinimumPosition);
}

- (NSString *)syncButtonTitle
{
  return @"Sync";
}

- (NSString *)autoSyncButtonTitle
{
  return @"Auto-sync";
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
  return self.filesWithStatus.count;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item;
{
  return [self.filesWithStatus objectAtIndex:index];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
  return NO;
}



- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(KDocumentVersionedFile *)file
{
  NSView *view = [outlineView makeViewWithIdentifier:tableColumn.identifier owner:self];
  NSImageView *iconView;
  NSTextField *filenameField;
  NSTextField *pathField;
  NSTextField *statusField;
  if (view) {
    filenameField = [view viewWithTag:1];
    pathField = [view viewWithTag:2];
    iconView = [view viewWithTag:3];
    statusField = [view viewWithTag:4];
  } else {
    view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, tableColumn.width, outlineView.rowHeight)];
    
    filenameField = [[NSTextField alloc] initWithFrame:NSMakeRect(37, 17, tableColumn.width - 37, 20)];
    filenameField.autoresizingMask = NSViewWidthSizable;
    filenameField.backgroundColor = [NSColor clearColor];
    filenameField.bordered = NO;
    filenameField.editable = NO;
    filenameField.font = [NSFont systemFontOfSize:[NSFont systemFontSize]];
    filenameField.tag = 1;
    NSTextFieldCell *cell = filenameField.cell;
    cell.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [view addSubview:filenameField];
    
    pathField = [[NSTextField alloc] initWithFrame:NSMakeRect(37, 0, tableColumn.width - 37, 17)];
    pathField.autoresizingMask = NSViewWidthSizable;
    pathField.backgroundColor = [NSColor clearColor];
    pathField.bordered = NO;
    pathField.editable = NO;
    pathField.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
    pathField.textColor = [[NSColor controlTextColor] colorWithAlphaComponent:0.7];
    pathField.tag = 2;
    cell = pathField.cell;
    cell.lineBreakMode = NSLineBreakByTruncatingHead;
    [view addSubview:pathField];
    
    iconView = [[NSImageView alloc] initWithFrame:NSMakeRect(0, 4, 32, 32)];
    iconView.tag = 3;
    [view addSubview:iconView];
    
    statusField = [[NSTextField alloc] initWithFrame:NSMakeRect(37, 21, tableColumn.width - 37, 14)];
    statusField.autoresizingMask = NSViewMinXMargin;
    statusField.textColor = [NSColor colorWithDeviceRed:1.00 green:1.00 blue:1.00 alpha:1.0];
    statusField.bordered = NO;
    statusField.editable = NO;
    statusField.font = [NSFont boldSystemFontOfSize:[NSFont smallSystemFontSize]];
    cell = statusField.cell;
    cell.alignment = NSCenterTextAlignment;
    statusField.tag = 4;
    [view addSubview:statusField];
  }
  
  filenameField.stringValue = file.fileUrl.lastPathComponent;
  
  NSString *basePath = self.fileURL.path.stringByStandardizingPath.stringByAbbreviatingWithTildeInPath;
  NSString *path = file.fileUrl.path.stringByStandardizingPath.stringByAbbreviatingWithTildeInPath;
  if (path.length > basePath.length && [[path substringToIndex:basePath.length] isEqualToString:basePath]) {
    path = [path substringFromIndex:basePath.length + 1];
  }
  pathField.stringValue = path;
  
  iconView.image = [[NSWorkspace sharedWorkspace] iconForFile:file.fileUrl.path];
  
  statusField.stringValue = file.humanReadibleStatus;
  [statusField sizeToFit];
  [statusField setFrame:NSMakeRect(view.frame.size.width - statusField.frame.size.width - 8, statusField.frame.origin.y, statusField.frame.size.width + 4, 14)];
  if (file.isWarningStatus) {
    statusField.backgroundColor = [NSColor colorWithDeviceRed:0.71 green:0.19 blue:0.29 alpha:1.0];
  } else {
    statusField.backgroundColor = [NSColor colorWithDeviceRed:0.60 green:0.65 blue:0.70 alpha:1.0];
  }
  [filenameField setFrame:NSMakeRect(filenameField.frame.origin.x, filenameField.frame.origin.y, view.frame.size.width - statusField.frame.size.width - filenameField.frame.origin.x - 4, filenameField.frame.size.height)];
  
  return view;
}

- (NSArray *)fetchFilesWithStatus
{
  NSLog(@"%s: subclass should implement this.", __PRETTY_FUNCTION__);
  return @[];
}


#pragma mark - Core Version Control functionality 

- (void)commit
{
  NSLog(@"%s: subclass should implement this.", __PRETTY_FUNCTION__);
}

- (void)showAuthenticationDialog:(id)sender
{
  CGFloat textFieldHeight = 23;
  
  NSView *authenticationView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 280, 110)];
  
  self.usernameTextField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 10, 10)];
  self.usernameTextField.font = [NSFont systemFontOfSize:13];
  self.usernameTextField.stringValue = @"";
  [(NSTextFieldCell *)self.usernameTextField.cell setPlaceholderString:@"Username"];
  self.usernameTextField.backgroundColor = [NSColor clearColor];
  self.usernameTextField.frame = NSMakeRect(0, authenticationView.frame.size.height - textFieldHeight - 10, 245, textFieldHeight);
  [authenticationView addSubview:self.usernameTextField];

  self.passwordTextField = [[NSSecureTextField alloc] initWithFrame:NSMakeRect(0, 0, 10, 10)];
  self.passwordTextField.font = [NSFont systemFontOfSize:13];
  self.passwordTextField.stringValue = @"";
  [(NSTextFieldCell *)self.passwordTextField.cell setPlaceholderString:@"Password"];
  self.passwordTextField.backgroundColor = [NSColor clearColor];
  self.passwordTextField.frame = NSMakeRect(0, authenticationView.frame.size.height - 2 * (textFieldHeight + 10), 245, textFieldHeight);
  [authenticationView addSubview:self.passwordTextField];
  
  self.storePasswordButton = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 10, 10)];
  self.storePasswordButton.title = @"Save password in Keychain";
  self.storePasswordButton.buttonType = NSSwitchButton;
  self.storePasswordButton.bezelStyle = NSRoundedBezelStyle;
  [self.storePasswordButton sizeToFit];
  self.storePasswordButton.frame = NSMakeRect(0, 10, 200, 20);
  [authenticationView addSubview:self.storePasswordButton];
  
  NSAlert *alert = [[NSAlert alloc] init];
  [alert addButtonWithTitle:@"OK"];
  [alert addButtonWithTitle:@"Cancel"];
  [alert setMessageText:@"Repository Authenticate"];
  [alert setInformativeText:@"For Ketchup to sync with your remote server we need a username and password"];
  [alert setAlertStyle:NSInformationalAlertStyle];
  [alert setAccessoryView:authenticationView];
  NSInteger result = [alert runModal];
  
  if ( result == NSAlertFirstButtonReturn ) { // OK button
    NSLog(@"first button");
  }
//  else if ( result == NSAlertSecondButtonReturn ) { // Cancel button
//    NSLog(@"second button");
//  }
}


@end
