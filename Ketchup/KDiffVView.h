//
//  KDiffVView.h
//  Ketchup
//
//  Created by Abhi Beckert on 27/06/2013.
//  Copyright (c) 2013 Abhi Beckert. All rights reserved.
//

@import Cocoa;

@interface KDiffVView : NSView

@property NSTextStorage *textStorageNew; // the entire new string, with syntax highlighting
@property NSTextStorage *textStorageOld; // the entire old string, with syntax highlighting

@end
