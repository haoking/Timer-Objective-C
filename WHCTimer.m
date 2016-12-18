//
//  WHCTimer.m
//  WHCAPP
//
//  Created by Haochen Wang on 11/29/16.
//  Copyright © 2016 WHC. All rights reserved.
//

#import "WHCTimer.h"
#import <libkern/OSAtomic.h>

@interface WHCTimer ()
{
    uint32_t _timerIsInvalidated;
}

@property (nonatomic, assign) NSTimeInterval timeInterval;
@property (nonatomic, weak) id target;
@property (nonatomic, assign) SEL selector;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong) dispatch_source_t timer;

@property (atomic, assign) NSTimeInterval tolerance;
@property (nonatomic, assign) BOOL repeats;

@end

@implementation WHCTimer

@synthesize tolerance = _tolerance;


-(id)initWithTimeInterval:(NSTimeInterval)timeInterval
                   target:(id)target
                 selector:(SEL)selector
                  repeats:(BOOL)repeats
{
    self = [super init];
    if (!self)
    {
        return nil;
    }
    self.timeInterval = timeInterval;
    self.target = target;
    self.selector = selector;
    self.repeats = repeats;

    NSString *queueName = [NSString stringWithFormat:@"WHCTimer.%p", self];
    self.serialQueue = dispatch_queue_create([queueName cStringUsingEncoding:NSASCIIStringEncoding], DISPATCH_QUEUE_SERIAL);
    dispatch_set_target_queue(self.serialQueue, dispatch_get_main_queue());

    self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,
                                        0,
                                        0,
                                        self.serialQueue);
    [self start];
    return self;
}

+(instancetype)timerCreateWithTimeInterval:(NSTimeInterval)timeInterval
                                    target:(id)target
                                  selector:(SEL)selector
                                   repeats:(BOOL)repeats

{
    return [[self alloc] initWithTimeInterval:timeInterval target:target selector:selector repeats:repeats];
}

- (void)setTolerance:(NSTimeInterval)tolerance
{
    @synchronized(self)
    {
        if (tolerance != _tolerance)
        {
            _tolerance = tolerance;

            [self resetTimerProperties];
        }
    }
}

- (NSTimeInterval)tolerance
{
    @synchronized(self)
    {
        return _tolerance;
    }
}

- (void)resetTimerProperties
{
    int64_t intervalInNanoseconds = (int64_t)(self.timeInterval * NSEC_PER_SEC);
    int64_t toleranceInNanoseconds = (int64_t)(self.tolerance * NSEC_PER_SEC);

    dispatch_source_set_timer(self.timer,
                              dispatch_time(DISPATCH_TIME_NOW, intervalInNanoseconds),
                              (uint64_t)intervalInNanoseconds,
                              toleranceInNanoseconds
                              );
}

- (void)start
{
    [self resetTimerProperties];

    __weak WHCTimer *weakSelf = self;

    dispatch_source_set_event_handler(self.timer, ^{
        [weakSelf timerFired];
    });

    dispatch_resume(self.timer);
}

- (void)fire
{
    [self timerFired];
}

- (void)cancel
{
    if (!OSAtomicTestAndSetBarrier(7, &_timerIsInvalidated))
    {
        dispatch_source_t timer = self.timer;
        dispatch_async(self.serialQueue, ^{
            dispatch_source_cancel(timer);
        });
    }
}

- (void)timerFired
{
    if (OSAtomicAnd32OrigBarrier(1, &_timerIsInvalidated))
    {
        return;
    }
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self.target performSelector:self.selector withObject:self];
    #pragma clang diagnostic pop
    if (!self.repeats)
    {
        [self cancel];
    }

}

- (void)dealloc
{
    [self cancel];
}



@end
