//
//  TUIPinchGestureRecognizer.m
//  TwUI
//
//  Created by 吴天 on 12/14/14.
//
//

#import "TUIPinchGestureRecognizer.h"
#import "TUIGestureRecognizer_Subclass.h"

@interface TUIPinchGestureRecognizer ()
{
    CGFloat           _initialTouchDistance;
    CGFloat           _initialTouchScale;
    NSTimeInterval    _lastTouchTime;
    CGFloat           _velocity;
    CGFloat           _previousVelocity;
    CGFloat           _scaleThreshold;
    CGAffineTransform _transform;
    CGPoint           _anchorSceneReferencePoint;
    NSTouch          *_touches[2];
    unsigned int      _endsOnSingleTouch:1;
}

@property (nonatomic) CGFloat maximumScale;
@property (nonatomic) CGFloat minimalScale;

@end

@implementation TUIPinchGestureRecognizer

- (instancetype)initWithTarget:(id)target action:(SEL)action
{
    if (self = [super initWithTarget:target action:action]) {
        _scale = 1;
        _maximumScale = 10;
        _minimalScale = 0.1;
    }
    return self;
}

- (void)reset
{
    [super reset];
    _scale = 1;
}

- (void)magnifyWithEvent:(NSEvent *)event
{
    TUIGestureRecognizerState state = self.state;
    
    switch (state) {
        case TUIGestureRecognizerStatePossible:
        {
            if (![self delegateGestureRecognizerShouldBegin]) {
                self.state = TUIGestureRecognizerStateFailed;
                return;
            }
            
//            _initialTouchScale = _scale;
            self.state = TUIGestureRecognizerStateBegan;
        }
            break;
        case TUIGestureRecognizerStateChanged:
        case TUIGestureRecognizerStateBegan:
        {
            CGFloat scale = self.scale;
            scale += (event.magnification / 3);
            scale = MIN(scale, _maximumScale);
            scale = MAX(scale, _minimalScale);
            
            self.scale = scale;
            
            self.state = TUIGestureRecognizerStateChanged;
        }
        default:
            break;
    }
}

- (void)endGestureWithEvent:(NSEvent *)event
{
    TUIGestureRecognizerState state = self.state;
    
    if (state == TUIGestureRecognizerStateBegan ||
        state == TUIGestureRecognizerStateChanged) {
        self.state = TUIGestureRecognizerStateEnded;
    }
}

@end
