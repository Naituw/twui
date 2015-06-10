//
//  TUIGestureRecognizer.h
//  TwUI
//
//  Created by 吴天 on 12/7/14.
//
//

#import <Foundation/Foundation.h>

@class TUIView;

typedef NS_ENUM(NSInteger, TUIGestureRecognizerState)
{
    TUIGestureRecognizerStatePossible,
    TUIGestureRecognizerStateBegan,
    TUIGestureRecognizerStateChanged,
    TUIGestureRecognizerStateEnded,
    TUIGestureRecognizerStateCancelled,
    TUIGestureRecognizerStateFailed,
    TUIGestureRecognizerStateRecognized = TUIGestureRecognizerStateEnded
};

@protocol TUIGestureRecognizerDelegate;

@interface TUIGestureRecognizer : NSObject

- (id)initWithTarget:(id)target action:(SEL)action;

- (void)addTarget:(id)target action:(SEL)action;
- (void)removeTarget:(id)target action:(SEL)action;

- (CGPoint)locationInView:(TUIView *)view;
- (CGPoint)locationOfTouch:(NSUInteger)touchIndex inView:(TUIView*)view; // the location of a particular touch

- (NSUInteger)numberOfTouches;

@property (nonatomic, assign) id<TUIGestureRecognizerDelegate> delegate;
@property (nonatomic, getter=isEnabled) BOOL enabled;
@property (nonatomic, readonly) TUIGestureRecognizerState state;
@property (nonatomic, readonly) TUIView * view;
@property (nonatomic, readonly) NSSet * touches;

@end

@protocol TUIGestureRecognizerDelegate <NSObject>

@optional
// called when a gesture recognizer attempts to transition out of TUIGestureRecognizerStatePossible. returning NO causes it to transition to TUIGestureRecognizerStateFailed
- (BOOL)gestureRecognizerShouldBegin:(TUIGestureRecognizer *)gestureRecognizer;

@end
