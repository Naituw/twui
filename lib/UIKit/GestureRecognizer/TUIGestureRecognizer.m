//
//  TUIGestureRecognizer.m
//  TwUI
//
//  Created by 吴天 on 12/7/14.
//
//

#import "TUIGestureRecognizer.h"
#import "TUIGestureRecognizer_Private.h"
#import "TUIGestureRecognizer_Subclass.h"

@interface _TUIGestureTargetAction : NSObject

@property (nonatomic, assign) id target;
@property (nonatomic, assign) SEL action;

@end

@interface TUIGestureRecognizer ()
{
    NSMutableArray * _registeredActions;
    NSMutableArray * _trackingEvents;
}

@end

@implementation TUIGestureRecognizer

- (instancetype)init
{
    if (self = [super init]) {
        _state = TUIGestureRecognizerStatePossible;
        _enabled = YES;
        
        _registeredActions = [NSMutableArray array];
        _trackingEvents = [NSMutableArray array];
    }
    return self;
}

- (id)initWithTarget:(id)target action:(SEL)action
{
    if (self = [self init]) {
        [self addTarget:target action:action];
    }
    return self;
}

- (void)addTarget:(id)target action:(SEL)action
{
    NSAssert(target != nil, @"target must not be nil");
    NSAssert(action != NULL, @"action must not be NULL");
    
    _TUIGestureTargetAction * actionRecord = [[_TUIGestureTargetAction alloc] init];
    actionRecord.action = action;
    actionRecord.target = target;
    
    [_registeredActions addObject:actionRecord];
}

- (void)removeTarget:(id)target action:(SEL)action
{
    _TUIGestureTargetAction * actionRecord = [[_TUIGestureTargetAction alloc] init];
    actionRecord.action = action;
    actionRecord.target = target;

    [_registeredActions removeObject:actionRecord];
}

- (void)setState:(TUIGestureRecognizerState)state
{
    // the docs didn't say explicitly if these state transitions were verified, but I suspect they are. if anything, a check like this
    // should help debug things. it also helps me better understand the whole thing, so it's not a total waste of time :)
    
    typedef struct {
        TUIGestureRecognizerState fromState;
        TUIGestureRecognizerState toState;
        BOOL shouldNotify;
        BOOL shouldReset;
    } StateTransition;
    
    #define NumberOfStateTransitions 9
    static const StateTransition allowedTransitions[NumberOfStateTransitions] = {
        // discrete gestures
        {TUIGestureRecognizerStatePossible,		TUIGestureRecognizerStateRecognized,     YES,    YES},
        {TUIGestureRecognizerStatePossible,		TUIGestureRecognizerStateFailed,         NO,     YES},
        
        // continuous gestures
        {TUIGestureRecognizerStatePossible,		TUIGestureRecognizerStateBegan,          YES,    NO },
        {TUIGestureRecognizerStateBegan,			TUIGestureRecognizerStateChanged,        YES,    NO },
        {TUIGestureRecognizerStateBegan,			TUIGestureRecognizerStateCancelled,      YES,    YES},
        {TUIGestureRecognizerStateBegan,			TUIGestureRecognizerStateEnded,          YES,    YES},
        {TUIGestureRecognizerStateChanged,		TUIGestureRecognizerStateChanged,        YES,    NO },
        {TUIGestureRecognizerStateChanged,		TUIGestureRecognizerStateCancelled,      YES,    YES},
        {TUIGestureRecognizerStateChanged,		TUIGestureRecognizerStateEnded,          YES,    YES}
    };
    
    const StateTransition *transition = NULL;
    
    for (NSUInteger t=0; t<NumberOfStateTransitions; t++) {
        if (allowedTransitions[t].fromState == _state && allowedTransitions[t].toState == state) {
            transition = &allowedTransitions[t];
            break;
        }
    }
    
    NSAssert2((transition != NULL), @"invalid state transition from %zd to %zd", _state, state);
    
    if (transition) {
        _state = transition->toState;
        
        if (transition->shouldNotify) {
            for (_TUIGestureTargetAction * actionRecord in _registeredActions) {
                // docs mention that the action messages are sent on the next run loop, so we'll do that here.
                // note that this means that reset can't happen until the next run loop, either otherwise
                // the state property is going to be wrong when the action handler looks at it, so as a result
                // I'm also delaying the reset call (if necessary) just below here.
                [actionRecord.target performSelector:actionRecord.action withObject:self afterDelay:0];
            }
        }
        
        if (transition->shouldReset) {
            // see note above about the delay
            [self performSelector:@selector(reset) withObject:nil afterDelay:0];
        }
    }
}

- (CGPoint)locationInView:(TUIView *)view
{
    CGFloat x = 0;
    CGFloat y = 0;
    CGFloat k = 0;
    
    for (NSEvent *event in _trackingEvents) {
        const CGPoint p = [view localPointForEvent:event];
        x += p.x;
        y += p.y;
        k++;
    }
    
    if (k > 0) {
        return CGPointMake(x/k, y/k);
    } else {
        return CGPointZero;
    }
}

- (NSSet *)touches
{
    NSEvent * event = [_trackingEvents lastObject];
    
    if (!event) {
        return nil;
    }
    
    return [event touchesMatchingPhase:NSTouchPhaseTouching inView:_view.nsView];
}

- (NSUInteger)numberOfTouches
{
    return self.touches.count;
}

- (void)_setView:(TUIView *)v
{
    [self reset];
    _view = v;
}

- (BOOL)_shouldAttemptToRecognize
{
    return (self.enabled &&
            self.state != TUIGestureRecognizerStateFailed &&
            self.state != TUIGestureRecognizerStateCancelled &&
            self.state != TUIGestureRecognizerStateEnded);
}

- (void)_recognizeEvent:(NSEvent *)event
{
    if (![self _shouldAttemptToRecognize]) {
        return;
    }
    
    [_trackingEvents removeAllObjects];
    if (event) {
        [_trackingEvents addObject:event];
    }
    
    switch (event.type) {
        case NSEventTypeSwipe:
            [self swipeWithEvent:event];
            break;
        case NSEventTypeRotate:
            [self rotateWithEvent:event];
            break;
        case NSEventTypeBeginGesture:
            [self beginGestureWithEvent:event];
            break;
        case NSEventTypeEndGesture:
            [self endGestureWithEvent:event];
            break;
        case NSEventTypeMagnify:
            [self magnifyWithEvent:event];
            break;
        case NSLeftMouseDown:
            [self mouseDown:event];
            break;
        case NSLeftMouseUp:
            [self mouseUp:event];
            break;
        case NSLeftMouseDragged:
            [self mouseDragged:event];
            break;
        case NSRightMouseUp:
            [self rightMouseUp:event];
            break;
        case NSRightMouseDown:
            [self rightMouseDown:event];
            break;
        case NSRightMouseDragged:
            [self rightMouseDragged:event];
            break;
        case NSScrollWheel:
            [self scrollWheel:event];
            break;
        default:
            break;
    }
}

- (void)reset
{
    _state = TUIGestureRecognizerStatePossible;
    [_trackingEvents removeAllObjects];
}

- (void)mouseUp:(NSEvent *)theEvent
{
    
}

- (void)mouseDown:(NSEvent *)theEvent
{
    
}

- (void)mouseDragged:(NSEvent *)theEvent
{
    
}

- (void)rightMouseUp:(NSEvent *)theEvent
{
    
}

- (void)rightMouseDown:(NSEvent *)theEvent
{
    
}

- (void)rightMouseDragged:(NSEvent *)theEvent
{
    
}

- (void)scrollWheel:(NSEvent *)theEvent
{
    
}

- (void)beginGestureWithEvent:(NSEvent *)event
{
    
}

- (void)endGestureWithEvent:(NSEvent *)event
{
    
}

- (void)magnifyWithEvent:(NSEvent *)event
{
    
}

- (void)rotateWithEvent:(NSEvent *)event
{
    
}

- (void)swipeWithEvent:(NSEvent *)event
{
    
}

@end

@implementation _TUIGestureTargetAction

- (BOOL)isEqual:(id)object
{
    if (object == self) {
        return YES;
    } else if ([object isKindOfClass:[_TUIGestureTargetAction class]]) {
        return ([object target] == self.target && [object action] == self.action);
    } else {
        return NO;
    }
}

@end
