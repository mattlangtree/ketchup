//
//  DuxPHPLanguage.h
//  Dux
//
//  Created by Abhi Beckert on 2011-11-16.
//  
//  This is free and unencumbered software released into the public domain.
//  For more information, please refer to <http://unlicense.org/>
//

#import "DuxLanguage.h"
#import "DuxPHPBaseElement.h"

@interface DuxPHPLanguage : DuxLanguage

+ (NSIndexSet *)keywordIndexSet;
+ (NSRange)keywordIndexRange;
+ (id)keywordIndexString;

- (void)findKeywordsInString:(NSString *)string inRange:(NSRange)range;

@end
