/*
 Copyright 2011 Twitter, Inc.
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this work except in compliance with the License.
 You may obtain a copy of the License in the LICENSE file, or at:
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "TUIView.h"

@interface TUIViewAnimation : NSObject <CAAnimationDelegate>
{
	void *context;
	NSString *animationID;
    
	id __weak delegate;
	SEL animationWillStartSelector;
	SEL animationDidStopSelector;
	void (^animationCompletionBlock)(BOOL finished);
	
    NSUInteger _waitingAnimations;
    
    NSTimeInterval _animationDelay;
    NSTimeInterval _animationDuration;
    TUIViewAnimationCurve _animationCurve;
    BOOL _animationBeginsFromCurrentState;
    BOOL _animationRepeatAutoreverses;
    float _animationRepeatCount;
    CFTimeInterval _animationBeginTime;
    
    CABasicAnimation * _animationTemplate;
}

@property (nonatomic, assign) void *context;
@property (nonatomic, copy) NSString *animationID;

@property (nonatomic, strong) NSMutableSet * animatingViews;

@property (nonatomic, weak) id delegate;
@property (nonatomic, assign) SEL animationWillStartSelector;
@property (nonatomic, assign) SEL animationDidStopSelector;
@property (nonatomic, copy) void (^animationCompletionBlock)(BOOL finished);

- (void)setAnimationBeginsFromCurrentState:(BOOL)beginFromCurrentState;
- (void)setAnimationCurve:(TUIViewAnimationCurve)curve;
- (void)setAnimationDelay:(NSTimeInterval)delay;
- (void)setAnimationDuration:(NSTimeInterval)duration;
- (void)setAnimationRepeatAutoreverses:(BOOL)repeatAutoreverses;
- (void)setAnimationRepeatCount:(float)repeatCount;

- (id)actionForView:(TUIView *)view forKey:(NSString *)keyPath;

@end

static CAMediaTimingFunction * CAMediaTimingFunctionFromTUIViewAnimationCurve(TUIViewAnimationCurve curve) {
    NSString *functionName = kCAMediaTimingFunctionEaseInEaseOut;
    switch(curve) {
        case TUIViewAnimationCurveLinear:
            functionName = kCAMediaTimingFunctionLinear;
            break;
        case TUIViewAnimationCurveEaseIn:
            functionName = kCAMediaTimingFunctionEaseIn;
            break;
        case TUIViewAnimationCurveEaseOut:
            functionName = kCAMediaTimingFunctionEaseOut;
            break;
        case TUIViewAnimationCurveEaseInOut:
            functionName = kCAMediaTimingFunctionEaseInEaseOut;
            break;
    }
    return [CAMediaTimingFunction functionWithName:functionName];
}

@implementation TUIViewAnimation

@synthesize context;
@synthesize animationID;

@synthesize delegate;
@synthesize animationWillStartSelector;
@synthesize animationDidStopSelector;
@synthesize animationCompletionBlock;

- (id)init
{
    return [self initWithBasicAnimation:[CABasicAnimation animation]];
}

- (instancetype)initWithBasicAnimation:(CABasicAnimation *)animation
{
	if((self = [super init]))
	{
        _waitingAnimations = 1;
        _animationDuration = 0.2;
        _animationCurve = TUIViewAnimationCurveEaseInOut;
        _animationBeginsFromCurrentState = NO;
        _animationRepeatAutoreverses = NO;
        _animationRepeatCount = 0;
        _animationBeginTime = CACurrentMediaTime();
        _animatingViews = [[NSMutableSet alloc] initWithCapacity:0];
        _animationTemplate = animation;
	}
	return self;
}

- (void)dealloc
{
	if (animationCompletionBlock != nil) {
		animationCompletionBlock(NO);
        animationCompletionBlock = nil;
		
		NSAssert(animationCompletionBlock == nil, @"animationCompletionBlock should be nil after executing from dealloc");
	}
}

- (CAAnimation *)addAnimation:(CAAnimation *)animation
{
    animation.timingFunction = CAMediaTimingFunctionFromTUIViewAnimationCurve(_animationCurve);
    animation.duration = _animationDuration;
    animation.beginTime = _animationBeginTime + _animationDelay;
    animation.repeatCount = _animationRepeatCount;
    animation.autoreverses = _animationRepeatAutoreverses;
    animation.fillMode = kCAFillModeBackwards;
    animation.delegate = self;
    animation.removedOnCompletion = YES;
    _waitingAnimations++;
    return animation;
}

- (id)actionForView:(TUIView *)view forKey:(NSString *)keyPath
{
    [_animatingViews addObject:view];
    CALayer *layer = view.layer;
    CABasicAnimation *animation = nil;
    if (_animationTemplate) {
        animation = [_animationTemplate copyWithZone:nil];
        animation.keyPath = keyPath;
    } else {
        animation = [CABasicAnimation animationWithKeyPath:keyPath];
    }
//    animation.fromValue = _animationBeginsFromCurrentState ? [layer.presentationLayer valueForKey:keyPath] : nil;
    return [self addAnimation:animation];
}

- (void)setAnimationBeginsFromCurrentState:(BOOL)beginFromCurrentState
{
    _animationBeginsFromCurrentState = beginFromCurrentState;
}

- (void)setAnimationCurve:(TUIViewAnimationCurve)curve
{
    _animationCurve = curve;
}

- (void)setAnimationDelay:(NSTimeInterval)delay
{
    _animationDelay = delay;
}

- (void)setAnimationDuration:(NSTimeInterval)duration
{
    _animationDuration = duration;
}

- (void)setAnimationRepeatAutoreverses:(BOOL)repeatAutoreverses
{
    _animationRepeatAutoreverses = repeatAutoreverses;
}

- (void)setAnimationRepeatCount:(float)repeatCount
{
    _animationRepeatCount = repeatCount;
}

- (void)notifyAnimationsDidStopIfNeededUsingStatus:(BOOL)flag
{
    if (_waitingAnimations == 0) {
        if(delegate && animationDidStopSelector) {
            void (*animationDidStopIMP)(id,SEL,NSString*,NSNumber*,void*) = (void(*)(id,SEL,NSString*,NSNumber*,void*))[(NSObject *)delegate methodForSelector:animationDidStopSelector];
            animationDidStopIMP(delegate, animationDidStopSelector, animationID, [NSNumber numberWithBool:flag], context);
            animationDidStopSelector = NULL; // only fire this once
        } else if(animationCompletionBlock) {
            animationCompletionBlock(flag);
            self.animationCompletionBlock = nil; // only fire this once
        }
        [_animatingViews removeAllObjects];
    }
}

- (void)animationDidStart:(CAAnimation *)anim
{
    //	NSLog(@"+animstart %d", ++animstart);
	if(delegate && animationWillStartSelector) {
		void (*animationWillStartIMP)(id,SEL,NSString*,void*) = (void(*)(id,SEL,NSString*,void*))[(NSObject *)delegate methodForSelector:animationWillStartSelector];
		animationWillStartIMP(delegate, animationWillStartSelector, animationID, context);
		animationWillStartSelector = NULL; // only fire this once
	}
}

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag
{
    _waitingAnimations--;
    [self notifyAnimationsDidStopIfNeededUsingStatus:flag];
}

- (void)commit
{
    _waitingAnimations--;
    [self notifyAnimationsDidStopIfNeededUsingStatus:YES];
}

@end


@implementation TUIView (TUIViewAnimation)

static NSMutableArray *AnimationStack = nil;

+ (NSMutableArray *)_animationStack
{
	if(!AnimationStack)
		AnimationStack = [[NSMutableArray alloc] init];
	return AnimationStack;
}

+ (TUIViewAnimation *)_currentAnimation
{
	return [AnimationStack lastObject];
}

+ (void)animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations
{
	[self animateWithDuration:duration animations:animations completion:NULL];
}

+ (void)animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion
{
    [self animateWithDuration:duration delay:0 animations:animations completion:completion];
}

+ (void)animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion
{
    [self animateWithDuration:duration delay:0 curve:TUIViewAnimationCurveEaseInOut animations:animations completion:completion];
}
+ (void)animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay curve:(TUIViewAnimationCurve)curve animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion
{
    [self beginAnimations:nil context:NULL];
	[self setAnimationDuration:duration];
    [self setAnimationDelay:delay];
    [self setAnimationCurve:curve];
	[[self _currentAnimation] setAnimationCompletionBlock:completion];
	animations();
	[self commitAnimations];
}

+ (void)animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay usingSpringWithDamping:(CGFloat)dampingRatio initialSpringVelocity:(CGFloat)velocity options:(TUIViewAnimationOptions)options animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion
{
    if (AtLeastElCapitan) {
        dampingRatio = MAX(dampingRatio, 0.01);
	    dampingRatio = MIN(dampingRatio, 1);
	    duration = MAX(duration, 0.1);
	    duration = MIN(duration, 50);
	    
	    CGFloat damping = dampingRatio * 19.05;
	    
	    CASpringAnimation * animation = [CASpringAnimation animation];
	    animation.damping = dampingRatio * 19.05; // same behavior as UIKit
	    animation.initialVelocity = velocity;
	    animation.stiffness = 150;
	    
	    CGFloat factor = 13.815;
	    animation.mass = duration / (factor / damping + pow(damping / 100, factor / 10));
	    
	    [self _beginAnimations:nil animation:[[TUIViewAnimation alloc] initWithBasicAnimation:animation] context:NULL];
	    [self setAnimationDuration:animation.settlingDuration];
	    [self setAnimationDelay:delay];
	    [[self _currentAnimation] setAnimationCompletionBlock:completion];
	    animations();
	    [self commitAnimations];
    } else {
        [self beginAnimations:nil context:NULL];
        [self setAnimationDuration:duration];
        [self setAnimationDelay:delay];
        [[self _currentAnimation] setAnimationCompletionBlock:completion];
        animations();
        [self commitAnimations];
    }
}

+ (void)beginAnimations:(NSString *)animationID context:(void *)context
{
    [self _beginAnimations:animationID animation:[[TUIViewAnimation alloc] init] context:context];
}

+ (void)_beginAnimations:(NSString *)animationID animation:(TUIViewAnimation *)animation context:(void *)context
{
	animation.context = context;
	animation.animationID = animationID;
	[[self _animationStack] addObject:animation];
	
	// setup defaults
	[self setAnimationDuration:0.25];
	[self setAnimationCurve:TUIViewAnimationCurveEaseInOut];
	
    //	NSLog(@"+++ %d", [[self _animationStack] count]);
}

+ (void)commitAnimations
{
    TUIViewAnimation * __autoreleasing animation = [self _currentAnimation]; // release in end of runloop
	[[self _animationStack] removeLastObject];
    [animation commit];
    //	NSLog(@"--- %d", [[self _animationStack] count]);
}

+ (void)setAnimationDelegate:(id)delegate
{
	[self _currentAnimation].delegate = delegate;
}

+ (void)setAnimationWillStartSelector:(SEL)selector                // default = NULL. -animationWillStart:(NSString *)animationID context:(void *)context
{
	[self _currentAnimation].animationWillStartSelector = selector;
}

+ (void)setAnimationDidStopSelector:(SEL)selector                  // default = NULL. -animationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context
{
	[self _currentAnimation].animationDidStopSelector = selector;
}

static CGFloat SlomoTime()
{
	if((NSUInteger)([NSEvent modifierFlags]&NSDeviceIndependentModifierFlagsMask) == (NSUInteger)(NSShiftKeyMask))
		return 5.0;
	return 1.0;
}

+ (void)setAnimationDuration:(NSTimeInterval)duration
{
	[[self _currentAnimation] setAnimationDuration:duration * SlomoTime()];
}

+ (void)setAnimationDelay:(NSTimeInterval)delay                    // default = 0.0
{
    [[self _currentAnimation] setAnimationDelay:delay * SlomoTime()];
}

+ (void)setAnimationStartDate:(NSDate *)startDate                  // default = now ([NSDate date])
{
	NSLog(@"%@ %@ unimplemented", self, NSStringFromSelector(_cmd));
}

+ (void)setAnimationCurve:(TUIViewAnimationCurve)curve              // default = UIViewAnimationCurveEaseInOut
{
    [[self _currentAnimation] setAnimationCurve:curve];
}

+ (void)setAnimationRepeatCount:(float)repeatCount                 // default = 0.0.  May be fractional
{
    [[self _currentAnimation] setAnimationRepeatCount:repeatCount];
}

+ (void)setAnimationRepeatAutoreverses:(BOOL)repeatAutoreverses    // default = NO. used if repeat count is non-zero
{
    [[self _currentAnimation] setAnimationRepeatAutoreverses:repeatAutoreverses];
}

+ (void)setAnimationIsAdditive:(BOOL)additive
{
    NSLog(@"%@ %@ unimplemented", self, NSStringFromSelector(_cmd));
}

+ (void)setAnimationBeginsFromCurrentState:(BOOL)fromCurrentState  // default = NO. If YES, the current view position is always used for new animations -- allowing animations to "pile up" on each other. Otherwise, the last end state is used for the animation (the default).
{
    [[self _currentAnimation] setAnimationBeginsFromCurrentState:YES];
}

+ (void)setAnimationTransition:(TUIViewAnimationTransition)transition forView:(TUIView *)view cache:(BOOL)cache  // current limitation - only one per begin/commit block
{
	NSLog(@"%@ %@ unimplemented", self, NSStringFromSelector(_cmd));
}

static BOOL disableAnimations = NO;

+ (void)setAnimationsEnabled:(BOOL)enabled block:(void(^)(void))block
{
	BOOL save = disableAnimations;
	disableAnimations = !enabled;
	block();
	disableAnimations = save;
}

+ (void)setAnimationsEnabled:(BOOL)enabled                         // ignore any attribute changes while set.
{
	disableAnimations = !enabled;
}

+ (BOOL)areAnimationsEnabled
{
	return !disableAnimations;
}

static BOOL animateContents = NO;

+ (void)setAnimateContents:(BOOL)enabled
{
	animateContents = enabled;
}

+ (BOOL)willAnimateContents
{
	return animateContents;
}

- (void)removeAllAnimations
{
	[self.layer removeAllAnimations];
	[self.subviews makeObjectsPerformSelector:@selector(removeAllAnimations)];
}

- (id<CAAction>)actionForLayer:(CALayer *)layer forKey:(NSString *)event
{
	if(disableAnimations == NO) {
        
        BOOL isContents = [event isEqualToString:@"contents"];
        
		if((animateContents == NO) && isContents)
			return (id<CAAction>)[NSNull null]; // default - don't animate contents
		
        if (isContents) {
            NSLog(@"23");
        }
        
		TUIViewAnimation * animation = [TUIView _currentAnimation];
        if (animation) {
            return [animation actionForView:self forKey:event];
        }
	}
	
	return (id<CAAction>)[NSNull null];
}

@end
