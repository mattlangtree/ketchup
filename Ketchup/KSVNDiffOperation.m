//
//  KSVNDiffOperation.m
//  Ketchup
//
//  Created by Abhi Beckert on 22/06/2013.
//  Copyright (c) 2013 Abhi Beckert. All rights reserved.
//

#import "KSVNDiffOperation.h"

@interface KSVNDiffOperation ()

@property NSArray *changes;

@end

@implementation KSVNDiffOperation

- (NSString *)svnLaunchPath
{
  static NSString *path = nil;
  
  if (path)
    return path;
  
  if ([[NSFileManager defaultManager] fileExistsAtPath:@"/usr/local/bin/svn"]) {
    path = @"/usr/local/bin/svn";
  } else {
    path = @"/usr/bin/svn";
  }
  
  return path;
}

- (instancetype)initWithFileUrl:(NSURL *)url
{
  if (!(self = [super initWithFileUrl:url]))
    return nil;
  
  self.changes = [self findChanges];
  
  return self;
}

- (NSArray *)findChanges
{
  NSString *textContent = [self runTask];
  if (!textContent)
    return @[];
  
  NSArray *lines = [self parseDiffOutput:textContent];
  KChange *change = nil;
  NSInteger leftRightLineCountDelta = 0;
  NSMutableArray *changes = @[].mutableCopy;
  for (NSDictionary *line in lines) {
    NSString *type = [line valueForKey:@"type"];
    
    if ([type isEqualToString:@"ChangedLinesStart"]) {
      if (change)
        [changes addObject:change];
      
      change = [[KChange alloc] init];
      leftRightLineCountDelta = 0;
    } else if ([type isEqualToString:@"NewLine"]) {
      leftRightLineCountDelta--;
      
      NSString *leftLine = [NSString stringWithFormat:@"%@   %@\n", [line valueForKey:@"lineNumber"], [line valueForKey:@"line"]];
      change.leftHighlightedRanges = [change.leftHighlightedRanges arrayByAddingObject:[NSValue valueWithRange:NSMakeRange(change.leftString.length - 1, leftLine.length)]];
      change.leftString = [change.leftString stringByAppendingString:leftLine];
    } else if ([type isEqualToString:@"OldLine"]) {
      leftRightLineCountDelta++;
      
      NSString *rightLine = [NSString stringWithFormat:@"%@   %@\n", [line valueForKey:@"lineNumber"], [line valueForKey:@"line"]];
      change.rightHighlightedRanges = [change.rightHighlightedRanges arrayByAddingObject:[NSValue valueWithRange:NSMakeRange(change.rightString.length - 1, rightLine.length)]];
      change.rightString = [change.rightString stringByAppendingString:rightLine];
    } else if ([type isEqualToString:@"UnchangedLine"]) {
      while (leftRightLineCountDelta > 0) {
        leftRightLineCountDelta--;
        NSString *leftLine = @" \n";
        change.leftHighlightedRanges = [change.leftHighlightedRanges arrayByAddingObject:[NSValue valueWithRange:NSMakeRange(change.leftString.length - 1, leftLine.length)]];
        change.leftString = [change.leftString stringByAppendingString:leftLine];
      }
      while (leftRightLineCountDelta < 0) {
        leftRightLineCountDelta++;
        NSString *rightLine = @" \n";
        change.rightHighlightedRanges = [change.rightHighlightedRanges arrayByAddingObject:[NSValue valueWithRange:NSMakeRange(change.rightString.length - 1, rightLine.length)]];
        change.rightString = [change.rightString stringByAppendingString:rightLine];
      }
      change.leftString = [change.leftString stringByAppendingString:[NSString stringWithFormat:@"%@   %@\n", [line valueForKey:@"newLineNumber"], [line valueForKey:@"line"]]];
      change.rightString = [change.rightString stringByAppendingString:[NSString stringWithFormat:@"%@   %@\n", [line valueForKey:@"oldLineNumber"], [line valueForKey:@"line"]]];
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
  task.launchPath = self.svnLaunchPath;
  task.arguments = @[@"diff", self.url.path];
  task.standardOutput = [NSPipe pipe];
  task.standardError = [NSPipe pipe];
  
  [task launch];
  [task waitUntilExit];
  
  // grab the output data, and check for an error
  NSData *outputData = [[(NSPipe *)task.standardOutput fileHandleForReading] readDataToEndOfFile];
  NSString *error = [[NSString alloc] initWithData:[[(NSPipe *)task.standardError fileHandleForReading] readDataToEndOfFile] encoding:NSUTF8StringEncoding];
  
  if (error.length > 0) {
    NSLog(@"Svn error: %@", error);
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
  
  KChange *change = nil;
  
  NSUInteger leftLineCounter = 0;
  NSUInteger rightLineCounter = 0;
  for (NSValue *rangeValue in [textContent lineEnumeratorForLinesInRange:NSMakeRange(0, textContent.length)]) {
    NSRange lineRange = rangeValue.rangeValue;
    
    if (!areScanningChangeset && [textContent characterAtIndex:lineRange.location] == '@' && [textContent characterAtIndex:lineRange.location + 1] == '@') {
      areScanningChangeset = YES;
      
      NSString *lineString = [textContent substringWithRange:lineRange];
      NSArray *matches = [changesetLineDeltaPattern matchesInString:lineString options:0 range:NSMakeRange(0, lineString.length)];
      
      rightLineRange.location = [[lineString substringWithRange:[[matches objectAtIndex:0] rangeAtIndex:1]] integerValue];
      rightLineRange.length = [[lineString substringWithRange:[[matches objectAtIndex:0] rangeAtIndex:2]] integerValue];
      
      leftLineRange.location = [[lineString substringWithRange:[[matches objectAtIndex:1] rangeAtIndex:1]] integerValue];
      leftLineRange.length = [[lineString substringWithRange:[[matches objectAtIndex:1] rangeAtIndex:2]] integerValue];
      
      leftLineCounter = leftLineRange.location - 1;
      rightLineCounter = rightLineRange.location - 1;
      
      [lines addObject:@{
                         @"type": @"ChangedLinesStart",
                         @"newLineNumberStart": [NSNumber numberWithUnsignedInteger:leftLineRange.location],
                         @"oldLineNumberStart": [NSNumber numberWithUnsignedInteger:rightLineRange.location]
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
      change.leftString = [change.leftString stringByAppendingString:[NSString stringWithFormat:@"%lu  %@\n", leftLineCounter, [textContent substringWithRange:lineRange]]];
      change.rightString = [change.rightString stringByAppendingString:[NSString stringWithFormat:@"%lu  %@\n", rightLineCounter, [textContent substringWithRange:lineRange]]];
      
      [lines addObject:@{
                         @"type": @"UnchangedLine",
                         @"newLineNumber": [NSNumber numberWithUnsignedInteger:leftLineCounter],
                         @"oldLineNumber": [NSNumber numberWithUnsignedInteger:rightLineCounter],
                         @"line": [textContent substringWithRange:NSMakeRange(lineRange.location + 1, lineRange.length - 1)]
                         }];
    }
  }
  NSLog(@"%@", lines);
  return lines.copy;
}

- (void)setChanges:(NSArray *)changes
{
  _changes = changes;
}

- (NSArray *)changes
{
  return _changes;
}

@end
