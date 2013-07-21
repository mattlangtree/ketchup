//
//  KGitDiffOperation.m
//  Ketchup
//
//  Created by Matt Langtree on 24/06/2013.
//  Copyright (c) 2013 Abhi Beckert. All rights reserved.
//

#import "KGitDiffOperation.h"

@implementation KGitDiffOperation

- (instancetype)initWithFileUrl:(NSURL *)url
{
  if (!(self = [super initWithFileUrl:url]))
    return nil;
  
  return self;
}

- (instancetype)initWithFileUrl:(NSURL *)url workingDirectoryURL:(NSURL *)workingDirectory
{
  if (!(self = [super initWithFileUrl:url]))
    return nil;
  self.workingDirectory = workingDirectory;
  
  return self;
}

+ (instancetype)diffOperationWithFileUrl:(NSURL *)url workingDirectoryURL:(NSURL *)workingDirectory
{
  return [[[self class] alloc] initWithFileUrl:url workingDirectoryURL:workingDirectory];
}

//- (NSString *)oldFileContents
//{
//    return @"not yet implemented";
//}
//
//- (NSArray *)changes
//{
//    return @[];
//}


- (NSString *)oldFileContents
{
  if (_oldFileContents)
    return _oldFileContents;
  
  NSString *showArgument = self.url.path.stringByStandardizingPath;
  showArgument = [showArgument substringFromIndex:self.workingDirectory.path.stringByStandardizingPath.length + 1];
  showArgument = [@"HEAD:" stringByAppendingString:showArgument];
  // run `git show HEAD:path/to/file`
  NSTask *task = [[NSTask alloc] init];
  task.launchPath = @"/usr/bin/git";
  task.arguments = @[@"show", showArgument];
  task.currentDirectoryPath = self.workingDirectory.path;
  task.standardOutput = [NSPipe pipe];
  task.standardError = [NSPipe pipe];
  
  [task launch];
  
  // grab the output data, and check for an error
  NSData *outputData = [[(NSPipe *)task.standardOutput fileHandleForReading] readDataToEndOfFile];
  NSString *error = [[NSString alloc] initWithData:[[(NSPipe *)task.standardError fileHandleForReading] readDataToEndOfFile] encoding:NSUTF8StringEncoding];
  
  if (error.length > 0) {
    NSLog(@"git error: %@", error);
    _oldFileContents = @"";
    return _oldFileContents;
  }
  
  _oldFileContents = [NSString stringWithUnknownData:outputData usedEncoding:NULL];
  if (!_oldFileContents) {
    NSLog(@"cannot read file %@", self.url);
    _oldFileContents = @"";
  }
  
  return _oldFileContents;
}

- (NSArray *)findChanges
{
  NSString *textContent = [self runTask];
  if (!textContent)
    return @[];
  
  NSArray *lines = [self parseDiffOutput:textContent];
  
  KChange *change = nil;
  NSMutableArray *changes = @[].mutableCopy;
  NSUInteger lastNewLineNumber = 0;
  NSUInteger lastOldLineNumber = 0;
  for (NSDictionary *line in lines) {
    NSString *type = [line valueForKey:@"type"];
    
    if ([type isEqualToString:@"ChangedLinesStart"]) {
      if (change) {
        [changes addObject:change];
        change = nil;
      }
      
      lastNewLineNumber = [[line valueForKey:@"newLineNumber"] unsignedIntegerValue];
      lastOldLineNumber = [[line valueForKey:@"oldLineNumber"] unsignedIntegerValue];
    } else if ([type isEqualToString:@"OldLine"]) {
      NSUInteger lineNumber = [[line valueForKey:@"lineNumber"] unsignedIntegerValue];
      
      if (!change) { // not parsing a change yet
        change = [[KChange alloc] init];
        change.newLineLocation = lastNewLineNumber + 1;
        change.newLineCount = 0;
        change.oldLineLocation = lineNumber;
        change.oldLineCount = 1;
      } else if ((change.oldLineLocation + change.oldLineCount) == lineNumber) { // extending the length of the "old" section of the change
        change.oldLineCount++;
      } else { // we were parsing a change, but now we're parsing a new change
        [changes addObject:change];
        
        change = [[KChange alloc] init];
        change.newLineLocation = lastNewLineNumber + 1;
        change.newLineCount = 0;
        change.oldLineLocation = lineNumber;
        change.oldLineCount = 1;
      }
      
      lastOldLineNumber = lineNumber;
    } else if ([type isEqualToString:@"NewLine"]) {
      NSUInteger lineNumber = [[line valueForKey:@"lineNumber"] unsignedIntegerValue];
      
      if (!change) { // not parsing a change yet
        change = [[KChange alloc] init];
        change.newLineLocation = lineNumber;
        change.newLineCount = 1;
        change.oldLineLocation = lastOldLineNumber + 1;
        change.oldLineCount = 0;
      } else if ((change.newLineLocation + change.newLineCount) == lineNumber) { // change exists, and we are extending the length of newLineCount
        change.newLineCount++;
      } else { // we were parsing a change, but now we're parsing a new one
        [changes addObject:change];
        
        change = [[KChange alloc] init];
        change.newLineLocation = lineNumber;
        change.newLineCount = 1;
        change.oldLineLocation = lastOldLineNumber + 1;
        change.oldLineCount = 0;
      }
      
      lastNewLineNumber = lineNumber;
    } else if ([type isEqualToString:@"UnchangedLine"]) {
      if (change) {
        [changes addObject:change];
        change = nil;
      }
      
      lastNewLineNumber = [[line valueForKey:@"newLineNumber"] unsignedIntegerValue];
      lastOldLineNumber = [[line valueForKey:@"oldLineNumber"] unsignedIntegerValue];
    }
  }
  if (change)
    [changes addObject:change];
  
  return changes.copy;
}

- (NSString *)runTask
{
  // run `svn diff file`
  NSTask *task = [[NSTask alloc] init];
  task.launchPath = @"/usr/bin/git";
  task.arguments = @[@"diff", @"--word-diff=porcelain", self.url.path];
  task.currentDirectoryPath = self.workingDirectory.path;
  task.standardOutput = [NSPipe pipe];
  task.standardError = [NSPipe pipe];
  
  NSLog(@"%@ %@",task.launchPath,task.arguments);
  
  [task launch];
  
  // grab the output data, and check for an error
  NSData *outputData = [[(NSPipe *)task.standardOutput fileHandleForReading] readDataToEndOfFile];
  NSString *error = [[NSString alloc] initWithData:[[(NSPipe *)task.standardError fileHandleForReading] readDataToEndOfFile] encoding:NSUTF8StringEncoding];
  
  if (error.length > 0) {
    NSLog(@"git diff error: %@", error);
    return nil;
  }
  
  NSString *textContent = [NSString stringWithUnknownData:outputData usedEncoding:NULL];
  if (!textContent) {
    NSLog(@"cannot diff file %@", self.url);
    return nil;
  }
  
  return textContent;
}

- (NSArray *)parseDiffOutput:(NSString *)textContent
{
  NSMutableArray *lines = @[].mutableCopy;
  
  BOOL areScanningChangeset = NO;
  NSRange leftLineRange = NSMakeRange(NSNotFound, 0);
  NSRange rightLineRange = NSMakeRange(NSNotFound, 0);
  NSRegularExpression *changesetLineDeltaPattern = [NSRegularExpression regularExpressionWithPattern:@"([0-9]+)\\,([0-9]+)" options:0 error:NULL];
  
  NSUInteger leftLineCounter = 0;
  NSUInteger rightLineCounter = 0;
  for (NSValue *rangeValue in [textContent lineEnumeratorForLinesInRange:NSMakeRange(0, textContent.length)]) {
    NSRange lineRange = rangeValue.rangeValue;
    
    if (!areScanningChangeset && [textContent characterAtIndex:lineRange.location] == '@' && [textContent characterAtIndex:lineRange.location + 1] == '@') {
      areScanningChangeset = YES;
      
      NSString *lineString = [textContent substringWithRange:lineRange];
      NSArray *matches = [changesetLineDeltaPattern matchesInString:lineString options:0 range:NSMakeRange(0, lineString.length)];
      
      leftLineRange.location = [[lineString substringWithRange:[[matches objectAtIndex:1] rangeAtIndex:1]] integerValue];
      leftLineRange.length = [[lineString substringWithRange:[[matches objectAtIndex:1] rangeAtIndex:2]] integerValue];
      
      rightLineRange.location = [[lineString substringWithRange:[[matches objectAtIndex:0] rangeAtIndex:1]] integerValue];
      rightLineRange.length = [[lineString substringWithRange:[[matches objectAtIndex:0] rangeAtIndex:2]] integerValue];
      
      leftLineCounter = leftLineRange.location - 1;
      rightLineCounter = rightLineRange.location - 1;
      
      [lines addObject:@{
                         @"type": @"ChangedLinesStart",
                         @"newLineNumber": [NSNumber numberWithUnsignedInteger:leftLineRange.location],
                         @"oldLineNumber": [NSNumber numberWithUnsignedInteger:rightLineRange.location]
                         }];
    } else if (areScanningChangeset && [textContent characterAtIndex:lineRange.location] == '+') {
      leftLineCounter++;
      
      [lines addObject:@{
                         @"type": @"NewLine",
                         @"lineNumber": [NSNumber numberWithUnsignedInteger:leftLineCounter],
                         @"line": [textContent substringWithRange:NSMakeRange(lineRange.location + 1, lineRange.length - 1)]
                         }];
    } else if (areScanningChangeset && [textContent characterAtIndex:lineRange.location] == '-') {
      rightLineCounter++;
      
      [lines addObject:@{
                         @"type": @"OldLine",
                         @"lineNumber": [NSNumber numberWithUnsignedInteger:rightLineCounter],
                         @"line": [textContent substringWithRange:NSMakeRange(lineRange.location + 1, lineRange.length - 1)]
                         }];
    } else if (areScanningChangeset) {
      leftLineCounter++;
      rightLineCounter++;
      
      [lines addObject:@{
                         @"type": @"UnchangedLine",
                         @"newLineNumber": [NSNumber numberWithUnsignedInteger:leftLineCounter],
                         @"oldLineNumber": [NSNumber numberWithUnsignedInteger:rightLineCounter],
                         @"line": [textContent substringWithRange:NSMakeRange(lineRange.location + 1, lineRange.length - 1)]
                         }];
    }
  }
  
  return lines.copy;
}

- (NSArray *)changes
{
  if (_changes)
    return _changes;
  
  _changes = [self findChanges];
  
  return _changes;
}

@end
