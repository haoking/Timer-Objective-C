//
//  WHCTimer.h
//  WHCAPP
//
//  Created by Haochen Wang on 11/29/16.
//  Copyright © 2016 WHC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WHCTimer : NSObject

+(instancetype)timerCreateWithTimeInterval:(NSTimeInterval)timeInterval
                                    target:(id)target
                                  selector:(SEL)selector
                                   repeats:(BOOL)repeats;

- (void)cancel;

- (void)fire;

@end
