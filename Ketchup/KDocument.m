//
//  KDocument.m
//  Ketchup
//
//  Created by Abhi Beckert on 2013-6-6.
//  Copyright (c) 2013 Abhi Beckert. All rights reserved.
//

#import "KDocument.h"
#import "KDocumentVersionedFile.h"
#import "KFilesWatcher.h"
#import "KChange.h"
#import "KDiffOperation.h"
#import "KSyncronizedScrollView.h"
#import "KDocumentController.h"

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
      
      kWorkingCopyStatusNoneString = NSLocalizedString(@"Checking Status", nil);
      kWorkingCopyStatusCheckingString = NSLocalizedString(@"Checking Status", nil);
      kWorkingCopyStatusSyncedString = NSLocalizedString(@"Synced with Remote", nil);
      kWorkingCopyStatusRemoteAheadString = NSLocalizedString(@"Remote contains newer commits", nil);
      kWorkingCopyStatusLocalAheadString = NSLocalizedString(@"Local contains newer commits", nil);
      
      self.status = kWorkingCopyStatusNone;
      
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

  [[KFilesWatcher sharedWatcher] startWatchingWithPath:self.fileURL.path];
  
  // create sidebar views
  self.sidebarView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, sidebarWidth, windowHeight)];
  [self.sidebarView setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameLightContent]];
  self.sidebarView.wantsLayer = YES;
  self.sidebarView.layer = [CAGradientLayer layer];
  self.sidebarView.layer.frame = self.sidebarView.bounds;
  self.sidebarView.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.94 green:0.94 blue:0.94 alpha:1.0f].CGColor;
//  ((CAGradientLayer *)self.sidebarView.layer).colors = @[(id)([NSColor colorWithDeviceRed:0.82 green:0.85 blue:0.88 alpha:1.0].CGColor), (id)([NSColor colorWithDeviceRed:0.87 green:0.89 blue:0.91 alpha:1.0].CGColor)];
  
  self.remoteView = [[NSView alloc] initWithFrame:NSMakeRect(0, windowHeight - 40, sidebarWidth, 40)];
  self.remoteView.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
  [self.sidebarView addSubview:self.remoteView];

  self.remoteSyncButton = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 10, 10)];
  self.remoteSyncButton.autoresizingMask = NSViewMinXMargin | NSViewMinYMargin;
  self.remoteSyncButton.title = [self syncButtonTitle];
  self.remoteSyncButton.buttonType = NSMomentaryLightButton;
  self.remoteSyncButton.bezelStyle = NSRoundedBezelStyle;
  self.remoteSyncButton.font = [NSFont fontWithName:@"HelveticaNeue" size:12.f];
  [self.remoteSyncButton sizeToFit];
  self.remoteSyncButton.frame = NSMakeRect(sidebarWidth - 16 - self.remoteSyncButton.frame.size.width, self.remoteView.frame.size.height - 5 - self.remoteSyncButton.frame.size.height, self.remoteSyncButton.frame.size.width + 6, self.remoteSyncButton.frame.size.height + 1);
  [self.remoteView addSubview:self.remoteSyncButton];
  [self.remoteSyncButton setTarget:nil];
  [self.remoteSyncButton setAction:@selector(syncWithRemote:)];
  
  self.remoteStatusIconView = [[NSImageView alloc] initWithFrame:NSMakeRect(13, 10, 16, 16)];
  self.remoteStatusIconView.image = [NSImage imageNamed:@"led-up-to-date"];
  [self.remoteView addSubview:self.remoteStatusIconView];
  
  self.remoteStatusField = [[NSTextField alloc] initWithFrame:NSMakeRect(40, 4, sidebarWidth - 50, 25)];
  self.remoteStatusField.autoresizingMask = NSViewWidthSizable;
  self.remoteStatusField.font = [NSFont fontWithName:@"HelveticaNeue-Bold" size:12.f];
  self.remoteStatusField.backgroundColor = [NSColor clearColor];
  self.remoteStatusField.textColor = [NSColor colorWithCalibratedRed:0.1 green:0.1 blue:0.1 alpha:1.0f];
  self.remoteStatusField.bordered = NO;
  self.remoteStatusField.editable = NO;
  self.remoteStatusField.stringValue = @"Synced with Remote";
  [self.remoteView addSubview:self.remoteStatusField];
  
  self.syncProgressIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(10, 0, sidebarWidth - 100, 25)];
  self.syncProgressIndicator.autoresizingMask = NSViewWidthSizable;
  [self.syncProgressIndicator setIndeterminate:YES];
  [self.remoteView addSubview:self.syncProgressIndicator];
  [self.syncProgressIndicator setHidden:YES];



  self.filesView = [[NSView alloc] initWithFrame:NSMakeRect(0, 200, sidebarWidth, windowHeight - 230)];
  self.filesView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  [self.sidebarView addSubview:self.filesView];
  
  self.filesLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 10, 10)];
  self.filesLabel.backgroundColor = [NSColor clearColor];
  self.filesLabel.autoresizingMask = NSViewMinYMargin;
  self.filesLabel.editable = NO;
  self.filesLabel.bordered = NO;
  self.filesLabel.font = [NSFont fontWithName:@"HelveticaNeue-Bold" size:12.f];
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
  self.filesOutlineView.rowHeight = 20;
  [self.filesOutlineView setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameLightContent]];

  
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
  self.commitLabel.font = [NSFont fontWithName:@"HelveticaNeue-Bold" size:12.f];
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
  self.commitAutoSyncButton.font = [NSFont fontWithName:@"HelveticaNeue" size:12.f];
  self.commitAutoSyncButton.buttonType = NSSwitchButton;
  self.commitAutoSyncButton.bezelStyle = NSRoundedBezelStyle;
  [self.commitAutoSyncButton sizeToFit];
  self.commitAutoSyncButton.frame = NSMakeRect(10, 10, sidebarWidth - 20, 20);
  [self.commitView addSubview:self.commitAutoSyncButton];
  
  [self.commitAutoSyncButton setTarget:self];
  [self.commitAutoSyncButton setAction:@selector(autoSyncButtonChanged:)];
  
  self.commitButton = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 10, 10)];
  self.commitButton.autoresizingMask = NSViewMinXMargin;
  self.commitButton.title = @"Commit";
  self.commitButton.font = [NSFont fontWithName:@"HelveticaNeue" size:12.f];
  self.commitButton.buttonType = NSMomentaryLightButton;
  self.commitButton.bezelStyle = NSRoundedBezelStyle;
  [self.commitButton sizeToFit];
  self.commitButton.frame = NSMakeRect(sidebarWidth - 16 - self.commitButton.frame.size.width, 4, self.commitButton.frame.size.width + 6, self.commitButton.frame.size.height + 1);
  [self.commitButton setAction:@selector(commit)];
  [self.commitButton setTarget:nil];
  [self.commitView addSubview:self.commitButton];
  
  self.loadingLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 10, 10)];
  self.loadingLabel.font = [NSFont boldSystemFontOfSize:16];
  self.loadingLabel.textColor = [NSColor whiteColor];
  self.loadingLabel.shadow = [[NSShadow alloc] init];
  self.loadingLabel.alignment = NSCenterTextAlignment;
  self.loadingLabel.stringValue = @"Sending...";
  self.loadingLabel.editable = NO;
  [self.loadingLabel sizeToFit];
  self.loadingLabel.backgroundColor = [NSColor colorWithCalibratedRed:0 green:0 blue:0 alpha:0.4];
  self.loadingLabel.bordered = NO;
  self.loadingLabel.frame = NSMakeRect(0, 0, sidebarWidth, commitMessageHeight);
  
  [self.commitView addSubview:self.loadingLabel];
  [self.loadingLabel setHidden:YES];


  // Files List Right Click Menu
  self.filesRightClickMenu = [[NSMenu alloc] init];
  NSMenuItem *menuItem = [self.filesRightClickMenu addItemWithTitle:@"Reveal in Finder" action:@selector(revealInFinder:) keyEquivalent:@""];
  NSMenuItem *openMenuItem = [self.filesRightClickMenu addItemWithTitle:@"Open in Default Editor" action:@selector(openInDefaultEditor:) keyEquivalent:@""];
  
  NSString *plistPath = [[NSBundle mainBundle] pathForResource:@"PreferredEditors" ofType:@"plist"];
  NSDictionary *editorsDictionary = [[NSDictionary alloc] initWithContentsOfFile:plistPath];
  
  NSLog(@"editors dictionary: %@",editorsDictionary);
  if ([[editorsDictionary allKeys] count] > 0) {
    [self.filesRightClickMenu addItem:[NSMenuItem separatorItem]];
    for (int i=0; i<[[editorsDictionary allKeys] count]; i++) {
      NSString *editor = [[editorsDictionary allKeys] objectAtIndex:i];
      NSString *openInString = [NSString stringWithFormat:@"Open in \"%@\"",editor];
      NSMenuItem *menuItem = [self.filesRightClickMenu addItemWithTitle:openInString action:@selector(openInEditor:) keyEquivalent:@""];
      [menuItem setTag:i];
    }
  }
  
  [self.filesRightClickMenu addItem:[NSMenuItem separatorItem]];
  NSMenuItem *discardChangesMenuItem = [self.filesRightClickMenu addItemWithTitle:@"Discard Changes..." action:@selector(discardChanges:) keyEquivalent:@""];
  [menuItem setTarget:nil];
  [openMenuItem setTarget:nil];
  [discardChangesMenuItem setTarget:nil];
  [self.filesOutlineView setMenu:self.filesRightClickMenu];
  
  [self documentSpecificViewCustomisations];


  // create content views
  self.contentView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, contentWidth, windowHeight)];
  
  // create split view
  self.windowSplitView = [[NSSplitView alloc] initWithFrame:[self.window.contentView bounds]];
  self.windowSplitView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  [self.windowSplitView setVertical:YES];
  self.windowSplitView.dividerStyle = NSSplitViewDividerStyleThin;
  self.windowSplitView.delegate = self;
  [self.windowSplitView addSubview:self.sidebarView];
  [self.windowSplitView addSubview:self.contentView];
  [self.windowSplitView setPosition:sidebarWidth ofDividerAtIndex:0];
  [self.window.contentView addSubview:self.windowSplitView];
  [self.windowSplitView adjustSubviews];
  
  [self.window makeFirstResponder:self.filesOutlineView];
  [self.window makeKeyAndOrderFront:self];
  
  // load files
  self.filesWithStatus = [self fetchFilesWithStatus];
  [self.filesOutlineView reloadData];

  [NSApp setDelegate:self];
  NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];
  [notifCenter addObserver:self selector:@selector(refreshFilesListFromNotification:) name:KFilesDidChangeNotification object:nil];

}

- (void)documentSpecificViewCustomisations
{
  
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

#pragma mark - OutlineView delegate methods
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
  NSButton *checkboxButton;
  NSImageView *iconView;
  NSTextField *filenameField;
  NSTextField *pathField;
  NSTextField *statusField;
  if (view) {
    filenameField = [view viewWithTag:1];
    pathField = [view viewWithTag:2];
    checkboxButton = [view viewWithTag:3];
    iconView = [view viewWithTag:4];
    statusField = [view viewWithTag:5];
  } else {
    view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, tableColumn.width, outlineView.rowHeight)];
    
    filenameField = [[NSTextField alloc] initWithFrame:NSMakeRect(58, 0, tableColumn.width - 58, 18)];
    filenameField.autoresizingMask = NSViewWidthSizable;
    filenameField.backgroundColor = [NSColor clearColor];
    filenameField.bordered = NO;
    filenameField.editable = NO;
    filenameField.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
    filenameField.tag = 1;
    NSTextFieldCell *cell = filenameField.cell;
    cell.lineBreakMode = NSLineBreakByTruncatingHead;
    [view addSubview:filenameField];

    checkboxButton = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 10, 10)];
    checkboxButton.title = nil;
    checkboxButton.buttonType = NSSwitchButton;
    checkboxButton.bezelStyle = NSRoundedBezelStyle;
    [checkboxButton sizeToFit];
    checkboxButton.frame = NSMakeRect(2, 0, 20, 20);
    [view addSubview:checkboxButton];
    checkboxButton.tag = 3;
    checkboxButton.state = NSOnState;
    checkboxButton.target = nil;
    checkboxButton.action = @selector(didClickFileCheckbox:);

    iconView = [[NSImageView alloc] initWithFrame:NSMakeRect(38, 2, 16, 16)];
    iconView.tag = 4;
    [view addSubview:iconView];

    statusField = [[NSTextField alloc] initWithFrame:NSMakeRect(37, 3, tableColumn.width - 37, 14)];
    statusField.autoresizingMask = NSViewMinXMargin;
    statusField.bordered = NO;
    statusField.editable = NO;
    statusField.font = [NSFont boldSystemFontOfSize:[NSFont smallSystemFontSize]];
    cell = statusField.cell;
    cell.alignment = NSCenterTextAlignment;
    statusField.tag = 5;
    [view addSubview:statusField];
  }
  
  filenameField.stringValue = file.fileUrl.lastPathComponent;
  
  NSString *basePath = self.fileURL.path.stringByStandardizingPath.stringByAbbreviatingWithTildeInPath;
  NSString *path = file.fileUrl.path.stringByStandardizingPath.stringByAbbreviatingWithTildeInPath;
  if (path.length > basePath.length && [[path substringToIndex:basePath.length] isEqualToString:basePath]) {
    path = [path substringFromIndex:basePath.length + 1];
  }
  filenameField.toolTip = path;

  iconView.image = [[NSWorkspace sharedWorkspace] iconForFile:file.fileUrl.path];

  statusField.stringValue = file.humanReadibleStatus;
  [statusField sizeToFit];
  [statusField setFrame:NSMakeRect(view.frame.size.width - statusField.frame.size.width - 8, statusField.frame.origin.y, statusField.frame.size.width + 4, 14)];
  if (file.isWarningStatus) {
    statusField.backgroundColor = [NSColor colorWithDeviceRed:0.71 green:0.19 blue:0.29 alpha:1.0];
    statusField.textColor = [NSColor whiteColor];
  } else {
    statusField.backgroundColor = [NSColor clearColor];
    statusField.textColor = [NSColor colorWithDeviceRed:0.60 green:0.65 blue:0.70 alpha:1.0];
    
  }
  
  [filenameField setFrame:NSMakeRect(filenameField.frame.origin.x, filenameField.frame.origin.y, view.frame.size.width - statusField.frame.size.width - filenameField.frame.origin.x - 4, filenameField.frame.size.height)];

  checkboxButton.state = (file.includeInCommit) ? NSOnState : NSOffState;

  return view;
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
  for (NSView *view in self.contentView.subviews.copy) {
    [view removeFromSuperview];
  }
  
  // figure out which file is selected
  if (self.filesOutlineView.selectedRow == -1) {
    return;
  }

  KDocumentVersionedFile *file = [self.filesWithStatus objectAtIndex:self.filesOutlineView.selectedRow];

  if ([self isImageFile:file.fileUrl]) {
    self.fileImageView = [[NSImageView alloc] initWithFrame:NSMakeRect(0, 0, self.contentView.frame.size.width, self.contentView.frame.size.height)];
    self.fileImageView.image = [[NSImage alloc] initWithContentsOfFile:file.fileUrl.path];
    [self.fileImageView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

    [self.contentView setSubviews:@[self.fileImageView]];
    return;
  }

  if ([self isDirectory:file.fileUrl]) {
    NSLog(@"is directory");
    return;
  }
  
  // create diff
  KDiffOperation *diffOperation = [self diffOperationForFile:file];
  
  // figure out what language to use
  DuxLanguage *chosenLanguage = [DuxPlainTextLanguage sharedInstance];
  for (Class language in [DuxLanguage registeredLanguages]) {
    if (![language isDefaultLanguageForURL:file.fileUrl textContents:[diffOperation newFileContents]])
      continue;
    
    chosenLanguage = [language sharedInstance];
    break;
  }
  
  // load changes
  NSArray *changes = diffOperation.changes;
  NSMutableSet *leftHighlightedRanges = [NSMutableSet set];
  NSMutableSet *rightHighlightedRanges = [NSMutableSet set];
  for (KChange *change in changes) {
    NSUInteger lineCounter = 0;
    NSRange newRange = NSMakeRange(NSNotFound, 0);
    for (NSValue *lineRange in [[diffOperation newFileContents] lineEnumeratorForLinesInRange:NSMakeRange(0, [diffOperation newFileContents].length)]) {
      lineCounter++;
      
      if (lineCounter == change.newLineLocation) {
        newRange.location = [lineRange rangeValue].location;
      } else if (lineCounter > change.newLineLocation && lineCounter <= (change.newLineLocation + change.newLineCount)) {
        newRange.length = ([lineRange rangeValue].location - newRange.location) - 1;
      } else if (lineCounter > (change.newLineLocation + change.newLineCount)) {
        break;
      }
    }
    [leftHighlightedRanges addObject:[NSValue valueWithRange:newRange]];
    
    lineCounter = 0;
    NSRange oldRange = NSMakeRange(NSNotFound, 0);
    for (NSValue *lineRange in [[diffOperation oldFileContents] lineEnumeratorForLinesInRange:NSMakeRange(0, [diffOperation oldFileContents].length)]) {
      lineCounter++;
      
      if (lineCounter == change.oldLineLocation) {
        oldRange.location = [lineRange rangeValue].location;
      } else if (lineCounter > change.oldLineLocation && lineCounter <= (change.oldLineLocation + change.oldLineCount)) {
        oldRange.length = ([lineRange rangeValue].location - oldRange.location) - 1;
      } else if (lineCounter > (change.oldLineLocation + change.oldLineCount)) {
        break;
      }
    }
    [rightHighlightedRanges addObject:[NSValue valueWithRange:oldRange]];
    
    
//    if (leftString.length > 0) {
//      [leftString appendString: @"\n\n⚡️  ⚡️  ⚡️\n\n\n"];
//      [rightString appendString:@"\n\n⚡️  ⚡️  ⚡️\n\n\n"];
//    }
//    
//    for (NSValue *highlightedRange in change.leftHighlightedRanges) {
//      [leftHighlightedRanges addObject:[NSValue valueWithRange:NSMakeRange(leftString.length - 1 + highlightedRange.rangeValue.location, highlightedRange.rangeValue.length)]];
//    }
//    for (NSValue *highlightedRange in change.rightHighlightedRanges) {
//      [rightHighlightedRanges addObject:[NSValue valueWithRange:NSMakeRange(rightString.length - 1 + highlightedRange.rangeValue.location, highlightedRange.rangeValue.length)]];
//    }
//    
//    [leftString appendString:change.leftString
//     ];
//    [rightString appendString:change.rightString];
  }
  
  CGFloat diffViewWidth = floor(self.contentView.frame.size.width / 2);
  
  // create left diff view
  self.leftDiffTextStorage = [[NSTextStorage alloc] initWithString:[diffOperation newFileContents] attributes:@{NSFontAttributeName:[DuxPreferences editorFont]}];
  self.leftSyntaxHighlighter = [[DuxSyntaxHighlighter alloc] init];
  self.leftDiffTextStorage.delegate = self.leftSyntaxHighlighter;
  [self.leftSyntaxHighlighter setBaseLanguage:chosenLanguage forTextStorage:self.leftDiffTextStorage];
  
  NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
  NSTextContainer *textContainer = [[NSTextContainer alloc] initWithContainerSize:NSMakeSize(diffViewWidth, FLT_MAX)];
  textContainer.widthTracksTextView = YES;
  
  [self.leftDiffTextStorage addLayoutManager:layoutManager];
  [layoutManager addTextContainer:textContainer];
  
  self.leftDiffView = [[DuxTextView alloc] initWithFrame:NSMakeRect(0, 0, diffViewWidth, 100) textContainer:textContainer];
  self.leftDiffView.editable = NO;
  self.leftDiffView.minSize = NSMakeSize(0, 100);
  self.leftDiffView.maxSize = NSMakeSize(FLT_MAX, FLT_MAX);
  [self.leftDiffView setVerticallyResizable:YES];
  [self.leftDiffView setHorizontallyResizable:NO];
  [self.leftDiffView setAutoresizingMask:NSViewWidthSizable];
  self.leftDiffView.usesFindBar = YES;
  self.leftDiffView.typingAttributes = @{NSFontAttributeName:[DuxPreferences editorFont]};
  self.leftDiffView.highlighter = self.leftSyntaxHighlighter;
  
  NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, diffViewWidth, self.contentView.frame.size.height)];
  scrollView.borderType = NSNoBorder;
  scrollView.hasVerticalScroller = YES;
  scrollView.hasHorizontalScroller = NO;
  scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable | NSViewMaxXMargin;
  scrollView.autoresizesSubviews = YES;
  scrollView.documentView = self.leftDiffView;
  if ([DuxPreferences editorDarkMode]) {
    scrollView.backgroundColor = [NSColor colorWithCalibratedWhite:0.2 alpha:1];
  }
  [self.contentView addSubview:scrollView];
  
  // make sure scroll bars are good
  [self.leftDiffView.layoutManager ensureLayoutForTextContainer:self.leftDiffView.textContainer];
  
  
  
  
  // create right diff view
  self.rightDiffTextStorage = [[NSTextStorage alloc] initWithString:[diffOperation oldFileContents] attributes:@{NSFontAttributeName:[DuxPreferences editorFont]}];
  self.rightSyntaxHighlighter = [[DuxSyntaxHighlighter alloc] init];
  self.rightDiffTextStorage.delegate = self.rightSyntaxHighlighter;
  [self.rightSyntaxHighlighter setBaseLanguage:chosenLanguage forTextStorage:self.rightDiffTextStorage];
  
  layoutManager = [[NSLayoutManager alloc] init];
  textContainer = [[NSTextContainer alloc] initWithContainerSize:NSMakeSize(diffViewWidth, FLT_MAX)];
  textContainer.widthTracksTextView = YES;
  
  [self.rightDiffTextStorage addLayoutManager:layoutManager];
  [layoutManager addTextContainer:textContainer];
  
  self.rightDiffView = [[DuxTextView alloc] initWithFrame:NSMakeRect(0, 0, diffViewWidth, 100) textContainer:textContainer];
  self.rightDiffView.editable = NO;
  self.rightDiffView.minSize = NSMakeSize(0, 100);
  self.rightDiffView.maxSize = NSMakeSize(FLT_MAX, FLT_MAX);
  [self.rightDiffView setVerticallyResizable:YES];
  [self.rightDiffView setHorizontallyResizable:NO];
  [self.rightDiffView setAutoresizingMask:NSViewWidthSizable];
  self.rightDiffView.usesFindBar = YES;
  self.rightDiffView.typingAttributes = @{NSFontAttributeName:[DuxPreferences editorFont]};
  self.rightDiffView.highlighter = self.rightSyntaxHighlighter;
  
  KSyncronizedScrollView *syncronizedScrollView = [[KSyncronizedScrollView alloc] initWithFrame:NSMakeRect(self.contentView.frame.size.width - diffViewWidth, 0, diffViewWidth, self.contentView.frame.size.height)];
  syncronizedScrollView.borderType = NSNoBorder;
  syncronizedScrollView.hasVerticalScroller = YES;
  syncronizedScrollView.hasHorizontalScroller = NO;
  syncronizedScrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable | NSViewMinXMargin;
  syncronizedScrollView.autoresizesSubviews = YES;
  syncronizedScrollView.documentView = self.rightDiffView;
  if ([DuxPreferences editorDarkMode]) {
    syncronizedScrollView.backgroundColor = [NSColor colorWithCalibratedWhite:0.2 alpha:1];
  }
  [syncronizedScrollView setSynchronizedScrollView:scrollView];
  [self.contentView addSubview:syncronizedScrollView];
  
  // highlight changes
  [self.leftDiffView setHighlightedRanges:leftHighlightedRanges.copy];
  [self.rightDiffView setHighlightedRanges:rightHighlightedRanges.copy];
  
  // after a moment, force a re-draw (i don't know why this is needed, but it is - otherwise the highilghted ranges are in the wrong position)
  double delayInSeconds = 0;
  dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
  dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
    [self.rightDiffView setNeedsDisplay:YES];
    [self.leftDiffView setNeedsDisplay:YES];
  });
}

- (void)refreshFilesListFromNotification:(NSNotification *)notification
{
  if (![self.window isKeyWindow]) {
    self.filesWithStatus = [self fetchFilesWithStatus];
    [self.filesOutlineView reloadData];
  }
}

- (BOOL)isImageFile:(NSURL *)url
{
  BOOL isImageFile = NO;

  NSString *utiValue;
  [url getResourceValue:&utiValue forKey:NSURLTypeIdentifierKey error:nil];
  if (utiValue)
  {
    isImageFile = UTTypeConformsTo((__bridge CFStringRef)utiValue, kUTTypeImage);
  }
  return isImageFile;
}

- (BOOL)isDirectory:(NSURL *)url
{
  NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:url.path error:nil];
  return [[attributes valueForKey:@"NSFileType"] isEqualToString:NSFileTypeDirectory];
}


- (NSArray *)fetchFilesWithStatus
{
  NSLog(@"%s: subclass should implement this.", __PRETTY_FUNCTION__);
  return @[];
}

- (KDiffOperation *)diffOperationForFile:(KDocumentVersionedFile *)file
{
  NSLog(@"%s: subclass should implement this.", __PRETTY_FUNCTION__);
  return nil;
}

- (void)didClickFileCheckbox:(NSOutlineView *)sender
{
  // Set attribute to let file know if it will be included in commit
  NSInteger row = [self.filesOutlineView rowForView:sender];
  KDocumentVersionedFile *file = [self.filesOutlineView itemAtRow:row];

  if (!file.includeInCommit) {
    return;
  }
  
  [self.filesWithStatus enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
    KDocumentVersionedFile *versionedFile = (KDocumentVersionedFile *)obj;
    if ([versionedFile isEqual:file]) {
      versionedFile.includeInCommit = NO;
    }
  }];

  [self.filesOutlineView reloadData];

  self.commitAutoSyncButton.state = NSOffState;
  [self autoSyncButtonChanged:self.commitAutoSyncButton];
}

#pragma mark - Core Version Control functionality 

- (void)commit
{
  [self.loadingLabel setHidden:NO];
}

- (void)commitDidFinish
{
  [self.loadingLabel setHidden:YES];
}

- (void)autoSyncButtonChanged:(id)sender
{
  
}

- (void)syncWithRemote:(id)sender
{
  self.remoteSyncButton.title = @"N/Imp.";
  [self.remoteSyncButton sizeToFit];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
    self.remoteSyncButton.title = [self syncButtonTitle];
    [self.remoteSyncButton sizeToFit];
  });
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
}

- (void)discardChangesInFile:(KDocumentVersionedFile *)versionedFile
{
  NSLog(@"%s: subclass should implement this.", __PRETTY_FUNCTION__);
}

#pragma mark - App Delegate methods

- (void)applicationDidBecomeActive:(NSNotification *)aNotification
{
}

#pragma mark - Filesystem App Delegate Methods

- (NSApplicationTerminateReply)applicationShouldTerminate: (NSApplication *)app
{
  [[KFilesWatcher sharedWatcher] stopWatching];
  return NSTerminateNow;
}

# pragma mark - Right Click menu items

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
  return YES;
}

- (void)revealInFinder:(NSMenuItem *)menuItem
{
  NSInteger clickedRow = [self.filesOutlineView clickedRow];
  KDocumentVersionedFile *fileForClickedRow = [self.filesOutlineView itemAtRow:clickedRow];
  [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[fileForClickedRow.fileUrl]];
}

- (void)openInDefaultEditor:(NSMenuItem *)menuItem
{
  NSInteger clickedRow = [self.filesOutlineView clickedRow];
  KDocumentVersionedFile *fileForClickedRow = [self.filesOutlineView itemAtRow:clickedRow];
  [[NSWorkspace sharedWorkspace] openFile:fileForClickedRow.fileUrl.path];
}

- (void)openInEditor:(NSMenuItem *)menuItem
{
  NSString *plistPath = [[NSBundle mainBundle] pathForResource:@"PreferredEditors" ofType:@"plist"];
  NSDictionary *editorsDictionary = [[NSDictionary alloc] initWithContentsOfFile:plistPath];
  NSString *appName = [[editorsDictionary allKeys] objectAtIndex:[menuItem tag]];
  
  NSInteger clickedRow = [self.filesOutlineView clickedRow];
  KDocumentVersionedFile *fileForClickedRow = [self.filesOutlineView itemAtRow:clickedRow];
  [[NSWorkspace sharedWorkspace] openFile:fileForClickedRow.fileUrl.path withApplication:appName];
}

- (void)discardChanges:(NSMenuItem *)menuItem
{
  NSInteger clickedRow = [self.filesOutlineView clickedRow];
  KDocumentVersionedFile *fileForClickedRow = [self.filesOutlineView itemAtRow:clickedRow];

  NSString *areYouSureString = [NSString stringWithFormat:@"Are you sure you want to discard your changes to \"%@\"?",fileForClickedRow.fileUrl.lastPathComponent];
  NSString *copyToTrashString;
  if (fileForClickedRow.status == KFileStatusUntracked) {
    copyToTrashString = @"A copy will be moved to the trash first.";
  }
  NSAlert *alert = [[NSAlert alloc] init];
  [alert addButtonWithTitle:@"Discard Changes"];
  [alert addButtonWithTitle:@"Cancel"];
  [alert setMessageText:areYouSureString];
  if (copyToTrashString) {
    [alert setInformativeText:copyToTrashString];
  }
  [alert setAlertStyle:NSWarningAlertStyle];
  NSInteger result = [alert runModal];

  if ( result == NSAlertFirstButtonReturn ) { // OK button
    [self discardChangesInFile:fileForClickedRow];
  }
}

- (void)updateRemoteSyncStatus
{
  switch (self.status) {
    case kWorkingCopyStatusNone:
      self.remoteStatusField.stringValue = kWorkingCopyStatusNoneString;
      break;
    case kWorkingCopyStatusChecking:
      self.remoteStatusField.stringValue = kWorkingCopyStatusCheckingString;
      break;
    case kWorkingCopyStatusSynced:
      self.remoteStatusField.stringValue = kWorkingCopyStatusSyncedString;
      break;
    case kWorkingCopyStatusRemoteAhead:
      self.remoteStatusField.stringValue = kWorkingCopyStatusRemoteAheadString;
      break;
    case kWorkingCopyStatusLocalAhead:
      self.remoteStatusField.stringValue = kWorkingCopyStatusLocalAheadString;
      break;
  }
}


@end
