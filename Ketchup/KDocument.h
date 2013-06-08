//
//  KDocument.h
//  Ketchup
//
//  Created by Abhi Beckert on 2013-6-6.
//  Copyright (c) 2013 Abhi Beckert. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

@interface KDocument : NSDocument <NSSplitViewDelegate, NSOutlineViewDataSource, NSOutlineViewDelegate>

// window (created by in xib file)
@property (strong) IBOutlet NSWindow *window;

// main window split view, and it's two child views
@property (strong) NSSplitView *windowSplitView;
@property (strong) NSView *sidebarView;
@property (strong) NSView *contentView;

// "remote" section at the top of the sidebar
@property (strong) NSView *remoteView;
@property (strong) NSTextField *remoteLabel;
@property (strong) NSButton *remoteSyncButton;
@property (strong) NSImageView *remoteStatusIconView;
@property (strong) NSTextField *remoteStatusField;

// "files" section in the sidebar
@property (strong) NSView *filesView;
@property (strong) NSTextField *filesLabel;
@property (strong) NSOutlineView *filesOutlineView;

// "commit" section at the bottom of the sidebar
@property (strong) NSView *commitView;
@property (strong) NSTextField *commitLabel;
@property (strong) NSTextView *commitTextView;
@property (strong) NSButton *commitAutoSyncButton;
@property (strong) NSButton *commitButton;

// main text view to display diff of the selected file
@property (strong) NSTextView *diffView;

// User authentication dialog
@property (strong) NSTextField *usernameTextField;
@property (strong) NSSecureTextField *passwordTextField;
@property (strong) NSButton *storePasswordButton;

- (void)showAuthenticationDialog:(id)sender;

@end
