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

#import "TUIScrollView.h"
#import "TUIKit.h"
#import "TUINSView.h"
#import "TUIScrollKnob.h"
#import "TUIView+Private.h"
#import "TUIPinchGestureRecognizer.h"

#define KNOB_Z_POSITION 6000

#define FORCE_ENABLE_BOUNCE 1

#define TUIScrollViewContinuousScrollDragBoundary 25.0
#define TUIScrollViewContinuousScrollRate         10.0

static const NSTimeInterval TUIScrollViewAnimationDuration = 0.33;

enum {
	ScrollPhaseNormal = 0,
	ScrollPhaseThrowingBegan = 1,
	ScrollPhaseThrowing = 2,
	ScrollPhaseThrowingEnded = 3,
};

enum {
  AnimationModeNone,
	AnimationModeThrow,
	AnimationModeScrollTo,
	AnimationModeScrollContinuous,
};

@interface TUIScrollView (Private)

- (BOOL)_pulling;
- (BOOL)_verticalScrollKnobNeededForContentSize:(CGSize)size;
- (BOOL)_horizonatlScrollKnobNeededForContentSize:(CGSize)size;
- (void)_updateScrollKnobs;
- (void)_updateScrollKnobsAnimated:(BOOL)animated;
- (void)_updateBounce;
- (void)_startDisplayLink:(int)scrollMode;

@end

@interface TUIScrollView () <TUIGestureRecognizerDelegate>
{
    CGFloat _lastScale;
    CGPoint _lastZoomPoint;
}

@property (nonatomic, strong) TUIPinchGestureRecognizer * pinchGestureRecognizer;
@property (nonatomic) BOOL zooming;
@property (nonatomic) BOOL zoomBouncing;

@end
@implementation TUIScrollView

@synthesize decelerationRate;
@synthesize resizeKnobSize;

+ (Class)layerClass
{
	return [CAScrollLayer class];
}

- (id)initWithFrame:(CGRect)frame
{
	if((self = [super initWithFrame:frame]))
	{
		_layer.masksToBounds = NO; // differs from UIKit

		decelerationRate = 0.88;
		
		_scrollViewFlags.bounceEnabled = (FORCE_ENABLE_BOUNCE || AtLeastLion || [[NSUserDefaults standardUserDefaults] boolForKey:@"ForceEnableScrollBouncing"]);
		_scrollViewFlags.alwaysBounceVertical = FALSE;
		_scrollViewFlags.alwaysBounceHorizontal = FALSE;
		
		_scrollViewFlags.verticalScrollIndicatorVisibility = TUIScrollViewIndicatorVisibleDefault;
		_scrollViewFlags.horizontalScrollIndicatorVisibility = TUIScrollViewIndicatorVisibleDefault;
		
		_horizontalScrollKnob = [[TUIScrollKnob alloc] initWithFrame:CGRectZero];
		_horizontalScrollKnob.scrollView = self;
		_horizontalScrollKnob.layer.zPosition = KNOB_Z_POSITION;
		_horizontalScrollKnob.hidden = YES;
		_horizontalScrollKnob.opaque = NO;
		[self addSubview:_horizontalScrollKnob];
		
		_verticalScrollKnob = [[TUIScrollKnob alloc] initWithFrame:CGRectZero];
		_verticalScrollKnob.scrollView = self;
		_verticalScrollKnob.layer.zPosition = KNOB_Z_POSITION;
		_verticalScrollKnob.hidden = YES;
		_verticalScrollKnob.opaque = NO;
		[self addSubview:_verticalScrollKnob];
        
        _maximumZoomScale = 1;
        _minimumZoomScale = 1;
        _bouncesZoom = YES;
        _zooming = NO;
        
        TUIPinchGestureRecognizer * pinch = [[TUIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinchGestureRecognized:)];
//        [self addGestureRecognizer:pinch];
        [self setPinchGestureRecognizer:pinch];
	}
	return self;
}

- (void)dealloc
{
	if (displayLink)
    {
        CVDisplayLinkRelease(displayLink);
    }
}

- (id<TUIScrollViewDelegate>)delegate
{
	return _delegate;
}

- (void)setDelegate:(id<TUIScrollViewDelegate>)d
{
	_delegate = d;
	_scrollViewFlags.delegateScrollViewDidScroll = [_delegate respondsToSelector:@selector(scrollViewDidScroll:)];
	_scrollViewFlags.delegateScrollViewWillBeginDragging = [_delegate respondsToSelector:@selector(scrollViewWillBeginDragging:)];
	_scrollViewFlags.delegateScrollViewDidEndDragging = [_delegate respondsToSelector:@selector(scrollViewDidEndDragging:)];
	_scrollViewFlags.delegateScrollViewWillShowScrollIndicator = [_delegate respondsToSelector:@selector(scrollView:willShowScrollIndicator:)];
	_scrollViewFlags.delegateScrollViewDidShowScrollIndicator = [_delegate respondsToSelector:@selector(scrollView:didShowScrollIndicator:)];
	_scrollViewFlags.delegateScrollViewWillHideScrollIndicator = [_delegate respondsToSelector:@selector(scrollView:willHideScrollIndicator:)];
	_scrollViewFlags.delegateScrollViewDidHideScrollIndicator = [_delegate respondsToSelector:@selector(scrollView:didHideScrollIndicator:)];
    _scrollViewFlags.delegateScrollViewDidEndScroll = [_delegate respondsToSelector:@selector(scrollViewDidEndScroll:)];
    _scrollViewFlags.delegateViewForZoomingInScrollView = [_delegate respondsToSelector:@selector(viewForZoomingInScrollView:)];
    _scrollViewFlags.delegateScrollViewWillBeginZooming = [_delegate respondsToSelector:@selector(scrollViewWillBeginZooming:withView:)];
    _scrollViewFlags.delegateScrollViewDidEndZooming = [_delegate respondsToSelector:@selector(scrollViewDidEndZooming:withView:atScale:)];
    _scrollViewFlags.delegateScrollViewDidZoom = [_delegate respondsToSelector:@selector(scrollViewDidZoom:)];
}

- (TUIScrollViewIndicatorStyle)scrollIndicatorStyle
{
	return _scrollViewFlags.scrollIndicatorStyle;
}

- (void)setScrollIndicatorStyle:(TUIScrollViewIndicatorStyle)s
{
	_scrollViewFlags.scrollIndicatorStyle = s;
	_verticalScrollKnob.scrollIndicatorStyle = s;
	_horizontalScrollKnob.scrollIndicatorStyle = s;
}

/**
 * @brief Obtain the vertical scroll indiciator visibility
 * 
 * The scroll indicator visibiliy determines when scroll indicators are displayed.
 * Note that scroll indicators are never displayed if the content in the scroll view
 * is not large enough to require them.
 * 
 * @return vertical scroll indicator visibility
 */
-(TUIScrollViewIndicatorVisibility)verticalScrollIndicatorVisibility {
  return _scrollViewFlags.verticalScrollIndicatorVisibility;
}

/**
 * @brief Set the vertical scroll indiciator visibility
 * 
 * The scroll indicator visibiliy determines when scroll indicators are displayed.
 * Note that scroll indicators are never displayed if the content in the scroll view
 * is not large enough to require them.
 * 
 * @param visibility vertical scroll indicator visibility
 */
-(void)setVerticalScrollIndicatorVisibility:(TUIScrollViewIndicatorVisibility)visibility {
   _scrollViewFlags.verticalScrollIndicatorVisibility = visibility;
}

/**
 * @brief Obtain the horizontal scroll indiciator visibility
 * 
 * The scroll indicator visibiliy determines when scroll indicators are displayed.
 * Note that scroll indicators are never displayed if the content in the scroll view
 * is not large enough to require them.
 * 
 * @return horizontal scroll indicator visibility
 */
-(TUIScrollViewIndicatorVisibility)horizontalScrollIndicatorVisibility {
  return _scrollViewFlags.horizontalScrollIndicatorVisibility;
}

/**
 * @brief Set the horizontal scroll indiciator visibility
 * 
 * The scroll indicator visibiliy determines when scroll indicators are displayed.
 * Note that scroll indicators are never displayed if the content in the scroll view
 * is not large enough to require them.
 * 
 * @param visibility horizontal scroll indicator visibility
 */
-(void)setHorizontalScrollIndicatorVisibility:(TUIScrollViewIndicatorVisibility)visibility {
   _scrollViewFlags.horizontalScrollIndicatorVisibility = visibility;
}

/**
 * @brief Determine if the vertical scroll indicator is currently showing
 * @return showing or not
 */
-(BOOL)verticalScrollIndicatorShowing {
  return _scrollViewFlags.verticalScrollIndicatorShowing;
}

/**
 * @brief Determine if the horizontal scroll indicator is currently showing
 * @return showing or not
 */
-(BOOL)horizontalScrollIndicatorShowing {
  return _scrollViewFlags.horizontalScrollIndicatorShowing;
}

- (BOOL)isScrollEnabled
{
	return !_scrollViewFlags.scrollDisabled;
}

- (void)setScrollEnabled:(BOOL)b
{
	_scrollViewFlags.scrollDisabled = !b;
}

- (TUIEdgeInsets)contentInset
{
	return _contentInset;
}

- (void)setContentInset:(TUIEdgeInsets)i
{
	if(!TUIEdgeInsetsEqualToEdgeInsets(i, _contentInset)) {
		_contentInset = i;
		if(self._pulling){
			_scrollViewFlags.didChangeContentInset = 1;
		}else if(!self.dragging) {
      self.contentOffset = self.contentOffset;
		}
	}
}

- (CGRect)visibleRect
{
	CGRect b = self.bounds;
	CGPoint offset = self.contentOffset;
	offset.x = -offset.x;
	offset.y = -offset.y;
	b.origin = offset;
	return b;
}

/**
 * @brief Obtain the insets for currently visible scroll indicators
 * 
 * The insets describe the margins needed for content not to overlap the any
 * scroll indicators which are currently visible.  You can apply these insets
 * to #visibleRect to obtain a content frame what avoids the scroll indicators.
 * 
 * @return scroll indicator insets
 */
-(TUIEdgeInsets)scrollIndicatorInsets {
  return TUIEdgeInsetsMake(0, 0, (_scrollViewFlags.horizontalScrollIndicatorShowing) ? _horizontalScrollKnob.frame.size.height : 0, (_scrollViewFlags.verticalScrollIndicatorShowing) ? _verticalScrollKnob.frame.size.width : 0);
}

static CVReturn scrollCallback(CVDisplayLinkRef displayLink, const CVTimeStamp *now, const CVTimeStamp *outputTime, CVOptionFlags flagsIn, CVOptionFlags *flagsOut, void *displayLinkContext)
{
	@autoreleasepool {
		// perform drawing on the main thread
		TUIScrollView *scrollView = (__bridge id)displayLinkContext;
		[scrollView performSelectorOnMainThread:@selector(tick:) withObject:nil waitUntilDone:NO];
	}
	return kCVReturnSuccess;
}

- (void)_startDisplayLink:(int)scrollMode
{
	_scrollViewFlags.animationMode = scrollMode;
	_throw.t = CFAbsoluteTimeGetCurrent();
	_bounce.bouncing = NO;
	
	if (!displayLink) {
		CVDisplayLinkCreateWithActiveCGDisplays(&displayLink);
		CVDisplayLinkSetOutputCallback(displayLink, &scrollCallback, (__bridge void *)self);
		CVDisplayLinkSetCurrentCGDisplay(displayLink, kCGDirectMainDisplay);
	}
	CVDisplayLinkStart(displayLink);
}

- (void)_stopDisplayLink
{
	if (displayLink) {
		CVDisplayLinkStop(displayLink);
	}
	_scrollViewFlags.animationMode = AnimationModeNone;
	_bounce.bouncing = 0;
	[self _updateBounce];
	[self _updateScrollKnobsAnimated:NO];
}

- (void)willMoveToWindow:(TUINSWindow *)newWindow
{
	[super willMoveToWindow:newWindow];
	if(!newWindow) {
		x = YES;
		[self _stopDisplayLink];
	}
}

- (CGPoint)_fixProposedContentOffset:(CGPoint)offset
{
	CGRect b = self.bounds;
	CGSize s = _contentSize;
	
	s.height += _contentInset.top;
	
	CGFloat mx = offset.x + s.width;
	if(s.width > b.size.width) {
		if(mx < b.size.width) {
			offset.x = b.size.width - s.width;
		}
		if(offset.x > 0.0) {
			offset.x = 0.0;
		}
	} else {
		if(mx > b.size.width) {
			offset.x = b.size.width - s.width;
		}
		if(offset.x < 0.0) {
			offset.x = 0.0;
		}
	}

	CGFloat my = offset.y + s.height;
	if(s.height > b.size.height) { // content bigger than bounds
		if(my < b.size.height) {
			offset.y = b.size.height - s.height;
		}
		if(offset.y > 0.0) {
			offset.y = 0.0;
		}
	} else { // content smaller than bounds
		if(0) { // let it move around in bounds
			if(my > b.size.height) {
				offset.y = b.size.height - s.height;
			}
			if(offset.y < 0.0) {
				offset.y = 0.0;
			}
		}
		if(1) { // pin to top
			offset.y = b.size.height - s.height;
		}
	}
	
	return offset;
}

- (void)setResizeKnobSize:(CGSize)s
{
	if(AtLeastLion) {
		// ignore
	} else {
		resizeKnobSize = s;
	}
}

- (BOOL)_verticalScrollKnobNeededForContentSize:(CGSize)size {
  return (size.height > self.bounds.size.height);
}

- (BOOL)_horizontalScrollKnobNeededForContentSize:(CGSize)size {
  return (size.width > self.bounds.size.width);
}

- (void)_updateScrollKnobs {
  [self _updateScrollKnobsAnimated:FALSE];
}

- (void)_updateScrollKnobsAnimated:(BOOL)animated {
  // note: the animated option is currently ignored.
  
	CGPoint offset = _unroundedContentOffset;
	CGRect bounds = self.bounds;
	CGFloat knobSize = 12;
	
	BOOL vWasVisible = _scrollViewFlags.verticalScrollIndicatorShowing;
	BOOL vVisible = [self _verticalScrollKnobNeededForContentSize:self.contentSize];
	BOOL vEffectiveVisible = vVisible;
	BOOL hWasVisible = _scrollViewFlags.horizontalScrollIndicatorShowing;
	BOOL hVisible = [self _horizontalScrollKnobNeededForContentSize:self.contentSize];
	BOOL hEffectiveVisible = hVisible;
	
	switch(self.verticalScrollIndicatorVisibility){
    case TUIScrollViewIndicatorVisibleNever:
      vEffectiveVisible = _verticalScrollKnob.flashing;
      break;
    case TUIScrollViewIndicatorVisibleWhenScrolling:
	  vEffectiveVisible = vVisible && (_scrollViewFlags.animationMode != AnimationModeNone || _verticalScrollKnob.flashing);
      break;
    case TUIScrollViewIndicatorVisibleWhenMouseInside:
      vEffectiveVisible = vVisible && (_scrollViewFlags.animationMode != AnimationModeNone || _scrollViewFlags.mouseInside || _scrollViewFlags.mouseDownInScrollKnob || _verticalScrollKnob.flashing);
      break;
    case TUIScrollViewIndicatorVisibleAlways:
    default:
      // don't alter the visibility
      break;
	}
		
	switch(self.horizontalScrollIndicatorVisibility){
    case TUIScrollViewIndicatorVisibleNever:
      hEffectiveVisible = FALSE;
      break;
    case TUIScrollViewIndicatorVisibleWhenScrolling:
      hEffectiveVisible = vVisible && (_scrollViewFlags.animationMode != AnimationModeNone || _horizontalScrollKnob.flashing);
      break;
    case TUIScrollViewIndicatorVisibleWhenMouseInside:
      hEffectiveVisible = vVisible && (_scrollViewFlags.animationMode != AnimationModeNone || _scrollViewFlags.mouseInside || _scrollViewFlags.mouseDownInScrollKnob || _horizontalScrollKnob.flashing);
      break;
    case TUIScrollViewIndicatorVisibleAlways:
    default:
      // don't alter the visibility
      break;
	}
	
	float pullX =  self.bounceOffset.x + self.pullOffset.x;
	float pullY = -self.bounceOffset.y - self.pullOffset.y;
	float bounceX = pullX * 1.2;
	float bounceY = pullY * 1.2;
	
	_verticalScrollKnob.frame = CGRectMake(
    round(-offset.x + bounds.size.width - knobSize - pullX), // x
    round(-offset.y + (hVisible ? knobSize : 0) + resizeKnobSize.height + bounceY + _scrollIndicatorSlotInsets.bottom), // y
    knobSize, // width
    bounds.size.height - (hVisible ? knobSize : 0) - resizeKnobSize.height - _scrollIndicatorSlotInsets.bottom // height
  );
  
	_horizontalScrollKnob.frame = CGRectMake(
    round(-offset.x - bounceX), // x
    round(-offset.y + pullY), // y
    bounds.size.width - (vVisible ? knobSize : 0) - resizeKnobSize.width - _scrollIndicatorSlotInsets.right, // width
    knobSize // height
  );
  
  // notify the delegate about changes in vertical scroll indiciator visibility
  if(vWasVisible != vEffectiveVisible){
    if(vEffectiveVisible && _scrollViewFlags.delegateScrollViewWillShowScrollIndicator){
      [self.delegate scrollView:self willShowScrollIndicator:TUIScrollViewIndicatorVertical];
    }else if(!vEffectiveVisible && _scrollViewFlags.delegateScrollViewWillHideScrollIndicator){
      [self.delegate scrollView:self willHideScrollIndicator:TUIScrollViewIndicatorVertical];
    }
  }
  
  // notify the delegate about changes in horizontal scroll indiciator visibility
  if(hWasVisible != hEffectiveVisible){
    if(hEffectiveVisible && _scrollViewFlags.delegateScrollViewWillShowScrollIndicator){
      [self.delegate scrollView:self willShowScrollIndicator:TUIScrollViewIndicatorHorizontal];
    }else if(!hEffectiveVisible && _scrollViewFlags.delegateScrollViewWillHideScrollIndicator){
      [self.delegate scrollView:self willHideScrollIndicator:TUIScrollViewIndicatorHorizontal];
    }
  }
  
  _verticalScrollKnob.alpha = 1.0;
  _verticalScrollKnob.hidden = !vEffectiveVisible;
  _horizontalScrollKnob.alpha = 1.0;
  _horizontalScrollKnob.hidden = !hEffectiveVisible;
  
  // update scroll indiciator visible state
  _scrollViewFlags.verticalScrollIndicatorShowing = vEffectiveVisible;
  _scrollViewFlags.horizontalScrollIndicatorShowing = hEffectiveVisible;
  
  // notify the delegate about changes in vertical scroll indiciator visibility
  if(vWasVisible != vEffectiveVisible){
    if(vEffectiveVisible && _scrollViewFlags.delegateScrollViewDidShowScrollIndicator){
      [self.delegate scrollView:self didShowScrollIndicator:TUIScrollViewIndicatorVertical];
    }else if(!vEffectiveVisible && _scrollViewFlags.delegateScrollViewDidHideScrollIndicator){
      [self.delegate scrollView:self didHideScrollIndicator:TUIScrollViewIndicatorVertical];
    }
  }
  
  // notify the delegate about changes in horizontal scroll indiciator visibility
  if(hWasVisible != hEffectiveVisible){
    if(hEffectiveVisible && _scrollViewFlags.delegateScrollViewDidShowScrollIndicator){
      [self.delegate scrollView:self didShowScrollIndicator:TUIScrollViewIndicatorHorizontal];
    }else if(!hEffectiveVisible && _scrollViewFlags.delegateScrollViewDidHideScrollIndicator){
      [self.delegate scrollView:self didHideScrollIndicator:TUIScrollViewIndicatorHorizontal];
    }
  }
  
	if(vEffectiveVisible)
		[_verticalScrollKnob setNeedsLayout];
	if(hEffectiveVisible)
		[_horizontalScrollKnob setNeedsLayout];
	
}

- (void)layoutSubviews
{
	[self _setContentOffset:_unroundedContentOffset];
	[self _updateScrollKnobs];
}

static CGFloat lerp(CGFloat a, CGFloat b, CGFloat t)
{
	return a - t * (a+b);
}
					
static CGFloat clamp(CGFloat x, CGFloat min, CGFloat max)
{
	if(x < min) return min;
	if(x > max) return max;
	return x;
}

static CGFloat PointDist(CGPoint a, CGPoint b)
{
	CGFloat dx = a.x - b.x;
	CGFloat dy = a.y - b.y;
	return sqrt(dx*dx + dy*dy);
}

static CGPoint PointLerp(CGPoint a, CGPoint b, CGFloat t)
{
	CGPoint p;
	p.x = lerp(a.x, b.x, t);
	p.y = lerp(a.y, b.y, t);
	return p;
}

- (CGPoint)contentOffset
{
	CGPoint p = _unroundedContentOffset;
	p.x = roundf(p.x + self.bounceOffset.x + self.pullOffset.x);
	p.y = roundf(p.y + self.bounceOffset.y + self.pullOffset.y);
	return p;
}

/**
 * @internal
 * @brief Determine if we are pulling on either axis
 * @return pulling or not
 */
- (BOOL)_pulling {
  return _pull.xPulling || _pull.yPulling;
}

- (CGPoint)pullOffset
{
	if(_scrollViewFlags.bounceEnabled){
		return CGPointMake((_pull.xPulling) ? _pull.x : 0, (_pull.yPulling) ? _pull.y : 0);
	}else{
	  return CGPointZero;
	}
}

- (CGPoint)bounceOffset
{
	if(_scrollViewFlags.bounceEnabled){
		return _bounce.bouncing ? CGPointMake(_bounce.x, _bounce.y) : CGPointZero;
	}else{
	  return CGPointZero;
	}
}

- (void)_setContentOffset:(CGPoint)p
{
    NSLog(@"%@", NSStringFromPoint(p));

	_unroundedContentOffset = p;
	p.x = round(-p.x - self.bounceOffset.x - self.pullOffset.x);
	p.y = round(-p.y - self.bounceOffset.y - self.pullOffset.y);
	[((CAScrollLayer *)self.layer) scrollToPoint:p];
	if(_scrollViewFlags.delegateScrollViewDidScroll){
		[_delegate scrollViewDidScroll:self];
	}
}

- (void)setContentOffset:(CGPoint)p
{
	[self _setContentOffset:[self _fixProposedContentOffset:p]];
}

- (CGSize)contentSize
{
	return _contentSize;
}

- (void)setContentSize:(CGSize)s
{
	_contentSize = s;
}

- (CGFloat)topDestinationOffset
{
	CGRect visible = self.visibleRect;
	return -self.contentSize.height + visible.size.height;
}

/**
 * @brief Whether the scroll view bounces past the edge of content and back again
 * 
 * If the value of this property is YES, the scroll view bounces when it encounters a boundary of the content. Bouncing visually indicates
 * that scrolling has reached an edge of the content. If the value is NO, scrolling stops immediately at the content boundary without bouncing.
 * The default value varies based on the current AppKit version, user preferences, and other factors.
 * 
 * @return bounces or not
 */
-(BOOL)bounces {
  return _scrollViewFlags.bounceEnabled;
}

/**
 * @brief Whether the scroll view bounces past the edge of content and back again
 * 
 * If the value of this property is YES, the scroll view bounces when it encounters a boundary of the content. Bouncing visually indicates
 * that scrolling has reached an edge of the content. If the value is NO, scrolling stops immediately at the content boundary without bouncing.
 * The default value varies based on the current AppKit version, user preferences, and other factors.
 * 
 * @return bounces or not
 */
-(void)setBounces:(BOOL)bounces {
  _scrollViewFlags.bounceEnabled = bounces;
}

/**
 * @brief Always bounce content vertically
 * 
 * If this property is set to YES and bounces is YES, vertical dragging is allowed even if the content is smaller than the bounds of the scroll view. The default value is NO.
 * 
 * @return always bounce vertically or not
 */
-(BOOL)alwaysBounceVertical {
  return _scrollViewFlags.alwaysBounceVertical;
}

/**
 * @brief Always bounce content vertically
 * 
 * If this property is set to YES and bounces is YES, vertical dragging is allowed even if the content is smaller than the bounds of the scroll view. The default value is NO.
 * 
 * @param always always bounce vertically or not
 */
-(void)setAlwaysBounceVertical:(BOOL)always {
  _scrollViewFlags.alwaysBounceVertical = always;
}

/**
 * @brief Always bounce content horizontally
 * 
 * If this property is set to YES and bounces is YES, horizontal dragging is allowed even if the content is smaller than the bounds of the scroll view. The default value is NO.
 * 
 * @return always bounce vertically or not
 */
-(BOOL)alwaysBounceHorizontal {
  return _scrollViewFlags.alwaysBounceHorizontal;
}

/**
 * @brief Always bounce content horizontally
 * 
 * If this property is set to YES and bounces is YES, horizontal dragging is allowed even if the content is smaller than the bounds of the scroll view. The default value is NO.
 * 
 * @param always always bounce vertically or not
 */
-(void)setAlwaysBounceHorizontal:(BOOL)always {
  _scrollViewFlags.alwaysBounceHorizontal = always;
}

- (BOOL)isScrollingToTop
{
	if(displayLink) {
		if(_scrollViewFlags.animationMode == AnimationModeScrollTo) {
			if(roundf(destinationOffset.y) == roundf([self topDestinationOffset]))
				return YES;
		}
	}
	return NO;
}

- (void)setContentOffset:(CGPoint)contentOffset animated:(BOOL)animated
{
	if(animated) {
		destinationOffset = contentOffset;
		[self _startDisplayLink:AnimationModeScrollTo];
	} else {
		destinationOffset = contentOffset;
		[self setContentOffset:contentOffset];
        if (_scrollViewFlags.delegateScrollViewDidEndScroll) {
            [_delegate scrollViewDidEndScroll:self];
        }
	}
}

/**
 * @brief Begin scrolling continuously for a drag
 * 
 * Content is continuously scrolled in the direction of the drag until the end
 * of the content is reached or the operation is cancelled via
 * #endContinuousScrollAnimated:.
 * 
 * @param dragLocation the drag location
 * @param animated animate the scroll or not (this is currently ignored and the scroll is always animated)
 */
- (void)beginContinuousScrollForDragAtPoint:(CGPoint)dragLocation animated:(BOOL)animated {
  if(dragLocation.y <= TUIScrollViewContinuousScrollDragBoundary || dragLocation.y >= (self.bounds.size.height - TUIScrollViewContinuousScrollDragBoundary)){
    // note the drag offset
    _dragScrollLocation = dragLocation;
    // begin a continuous scroll
    [self _startDisplayLink:AnimationModeScrollContinuous];
  }else{
    [self endContinuousScrollAnimated:animated];
  }
}

/**
 * @brief Stop scrolling continuously for a drag
 * 
 * This method is the counterpart to #beginContinuousScrollForDragAtPoint:animated:
 * 
 * @param animated animate the scroll or not (this is currently ignored and the scroll is always animated)
 */
- (void)endContinuousScrollAnimated:(BOOL)animated {
  if(_scrollViewFlags.animationMode == AnimationModeScrollContinuous){
    [self _stopDisplayLink];
  }
}

static float clampBounce(float x) {
	x *= 0.4;
	float m = 60 * 60;
	if(x > 0.0f)
		return MIN(x, m);
	else
		return MAX(x, -m);
}

- (void)_startBounce
{
	if(!_bounce.bouncing) {
		_bounce.bouncing = TRUE;
		_bounce.x = 0.0f;
		_bounce.y = 0.0f;
		_bounce.vx = clampBounce( _throw.vx);
		_bounce.vy = clampBounce(-_throw.vy);
		_bounce.t = _throw.t;
	}
}

- (void)_updateBounce
{
	if(_bounce.bouncing) {
		CFAbsoluteTime t = CFAbsoluteTimeGetCurrent();
		double dt = t - _bounce.t;
		
		CGPoint F = CGPointZero;
		
		float tightness = 2.5f;
		float dampiness = 0.35f;
		
		// spring
		F.x = -_bounce.x * tightness;
		F.y = -_bounce.y * tightness;
		
		// damper
		if(fabsf(_bounce.x) > 0.0)
			F.x -= _bounce.vx * dampiness;
		if(fabsf(_bounce.y) > 0.0)
			F.y -= _bounce.vy * dampiness;
		
		_bounce.vx += F.x; // mass=1
		_bounce.vy += F.y;
		
		_bounce.x += _bounce.vx * dt;
		_bounce.y += _bounce.vy * dt;
		
		_bounce.t = t;
		
		if(fabsf(_bounce.vy) < 1.0 && fabsf(_bounce.y) < 1.0 && fabsf(_bounce.vx) < 1.0 && fabsf(_bounce.x) < 1.0) {
			[self _stopDisplayLink];
		}
		
		[self _updateScrollKnobs];
	}
}

- (void)tick:(NSTimer *)timer
{
	[self _updateBounce]; // can't do after _startBounce otherwise dt will be crazy
	
	if(self.nsWindow == nil) {
		NSLog(@"Warning: no window %d (should be 1)", x);
		[self _stopDisplayLink];
		return;
	}
	
	switch(_scrollViewFlags.animationMode) {
		case AnimationModeThrow: {
			
			CGPoint o = _unroundedContentOffset;
			CFAbsoluteTime t = CFAbsoluteTimeGetCurrent();
			double dt = t - _throw.t;
			o.x = o.x + _throw.vx * dt;
			o.y = o.y - _throw.vy * dt;
			
			CGPoint fixedOffset = [self _fixProposedContentOffset:o];
			if(!CGPointEqualToPoint(fixedOffset, o)) {
				[self _startBounce];
			}
			
			[self setContentOffset:o];
			
			_throw.vx *= decelerationRate;
			_throw.vy *= decelerationRate;
			_throw.t = t;
			
			if(_throw.throwing && !self._pulling && !_bounce.bouncing) {
				// may happen in the case where our we scrolled, then stopped, then lifted finger (didn't do a system-started throw, but timer started anyway to do something else)
				// todo - handle this before it happens, but keep this sanity check
				if(MAX(fabsf(_throw.vx), fabsf(_throw.vy)) < 0.1) {
					[self _stopDisplayLink];
				}
			}
			
			break;
		}
		case AnimationModeScrollTo: {
			
			CGPoint o = _unroundedContentOffset;
			CGPoint lastOffset = o;
			o.x = o.x * decelerationRate + destinationOffset.x * (1-decelerationRate);
			o.y = o.y * decelerationRate + destinationOffset.y * (1-decelerationRate);
			o = [self _fixProposedContentOffset:o];
			[self _setContentOffset:o];
			
			if((fabsf(o.x - lastOffset.x) < 0.1) && (fabsf(o.y - lastOffset.y) < 0.1)) {
				[self _stopDisplayLink];
				[self setContentOffset:destinationOffset];
			}
			
			break;
		}
    case AnimationModeScrollContinuous: {
      CGFloat direction;
      CGFloat distance;
      
      if(_dragScrollLocation.y <= TUIScrollViewContinuousScrollDragBoundary){
        distance = MAX(0, MIN(TUIScrollViewContinuousScrollDragBoundary, _dragScrollLocation.y));
        direction = 1;
      }else if(_dragScrollLocation.y >= (self.bounds.size.height - TUIScrollViewContinuousScrollDragBoundary)){
        distance = MAX(0, MIN(TUIScrollViewContinuousScrollDragBoundary, self.bounds.size.height - _dragScrollLocation.y));
        direction = -1;
      }else{
        return; // no scrolling; outside drag boundary
      }
      
			CGPoint offset = _unroundedContentOffset;
      CGFloat step = (1.0 - (distance / TUIScrollViewContinuousScrollDragBoundary)) * TUIScrollViewContinuousScrollRate;
			CGPoint dest = CGPointMake(offset.x, offset.y + (step * direction));
      
			[self setContentOffset:dest];
			
      break;
    }
	}
}

- (void)scrollRectToVisible:(CGRect)rect animated:(BOOL)animated
{
	CGRect visible = self.visibleRect;
	if(rect.origin.y < visible.origin.y) {
		// scroll down, have rect be flush with bottom of visible view
		[self setContentOffset:CGPointMake(0, -rect.origin.y) animated:animated];
	} else if(rect.origin.y + rect.size.height > visible.origin.y + visible.size.height) {
		// scroll up, rect to be flush with top of view
		[self setContentOffset:CGPointMake(0, -rect.origin.y + visible.size.height - rect.size.height) animated:animated];
	}
	[self.nsView invalidateHoverForView:self];
}

- (void)scrollToTopAnimated:(BOOL)animated
{
	[self setContentOffset:CGPointMake(0, [self topDestinationOffset]) animated:animated];
}

- (void)scrollToBottomAnimated:(BOOL)animated
{
	[self setContentOffset:CGPointMake(0, 0) animated:animated];
}

- (void)pageDown:(id)sender
{
	CGPoint o = self.contentOffset;
	o.y += roundf((self.visibleRect.size.height * 0.9));
	[self setContentOffset:o animated:YES];
}

- (void)pageUp:(id)sender
{
	CGPoint o = self.contentOffset;
	o.y -= roundf((self.visibleRect.size.height * 0.9));
	[self setContentOffset:o animated:YES];
}

- (void)flashScrollIndicators
{
	[_horizontalScrollKnob flash];
	[_verticalScrollKnob flash];
	[self _updateScrollKnobsAnimated:YES];
}

- (BOOL)isDragging
{
	return _scrollViewFlags.gestureBegan;
}

- (BOOL)isDecelerating {
	return _scrollViewFlags.animationMode == AnimationModeScrollTo;
}

/*
 
 10.6 throw sequence:
 
 - beginGestureWithEvent
 - ScrollPhaseNormal
 - ...
 - ScrollPhaseNormal
 - endGestureWithEvent
 - ScrollPhaseThrowingBegan
 
 [REDACTED] throw sequence:
 
 - beginGestureWithEvent
 - ScrollPhaseNormal
 - ...
 - ScrollPhaseNormal
 - endGestureWithEvent
 - ScrollPhaseNormal         <- ignore this
 - ScrollPhaseThrowingBegan
 
 */

- (void)beginGestureWithEvent:(NSEvent *)event
{
  
	if(_scrollViewFlags.delegateScrollViewWillBeginDragging){
		[_delegate scrollViewWillBeginDragging:self];
	}
	
	if(_scrollViewFlags.bounceEnabled) {
		_throw.throwing = 0;
		_scrollViewFlags.gestureBegan = 1; // this won't happen if window isn't key on 10.6, lame
	}
	
}

- (void)_startThrow
{
  
  if(!self._pulling){
    if(fabsf(_lastScroll.dy) < 2.0 && fabsf(_lastScroll.dx) < 2.0){
        if (_scrollViewFlags.delegateScrollViewDidEndScroll) {
            [_delegate scrollViewDidEndScroll:self];
        }
      return; // don't bother throwing
    }
  }
	
	if(!_throw.throwing) {
		_throw.throwing = TRUE;
		
		CFAbsoluteTime t = CFAbsoluteTimeGetCurrent();
		CFTimeInterval dt = t - _lastScroll.t;
		if(dt < 1 / 60.0) dt = 1 / 60.0;
		
		_throw.vx = _lastScroll.dx / dt;
		_throw.vy = _lastScroll.dy / dt;
		_throw.t = t;
		
		[self _startDisplayLink:AnimationModeThrow];
		
		if(_pull.xPulling) {
			_pull.xPulling = NO;
			if(signbit(_throw.vx) != signbit(_pull.x)) _throw.vx = 0.0;
			[self _startBounce];
			_bounce.x = _pull.x;
		}
		
		if(_pull.yPulling) {
			_pull.yPulling = NO;
			if(signbit(_throw.vy) != signbit(_pull.y)) _throw.vy = 0.0;
			[self _startBounce];
			_bounce.y = _pull.y;
		}
		
    if(self._pulling && _scrollViewFlags.didChangeContentInset){
      _scrollViewFlags.didChangeContentInset = 0;
      _bounce.x += _contentInset.left;
      _bounce.y += _contentInset.top;
      _unroundedContentOffset.x -= _contentInset.left;
      _unroundedContentOffset.y -= _contentInset.top;
    }
    
	}
	
}

- (void)endGestureWithEvent:(NSEvent *)event
{
  
	if(_scrollViewFlags.delegateScrollViewDidEndDragging){
		[_delegate scrollViewDidEndDragging:self];
	}
	
	if(_scrollViewFlags.bounceEnabled) {
		_scrollViewFlags.gestureBegan = 0;
		[self _startThrow];
		if(AtLeastLion) {
			_scrollViewFlags.ignoreNextScrollPhaseNormal_10_7 = 1;
		}
	}
	
    [self.superview endGestureWithEvent:event];
}

- (void)scrollWheel:(NSEvent *)event
{
	if(_contentSize.height <= CGRectGetHeight(self.bounds)) {
		[super scrollWheel:event];
	}
	
	if(self.scrollEnabled)
	{
		int phase = ScrollPhaseNormal;
		
		if(AtLeastLion) {
			SEL s = @selector(momentumPhase);
			if([event respondsToSelector:s]) {
				NSInteger (*imp)(id,SEL) = (NSInteger(*)(id,SEL))[event methodForSelector:s];
				NSInteger lionPhase = imp(event, s);
				
				switch(lionPhase) {
					case 1:
						phase = ScrollPhaseThrowingBegan;
						break;
					case 4:
						phase = ScrollPhaseThrowing;
						break;
					case 8:
						phase = ScrollPhaseThrowingEnded;
						break;
				}
			}
		} else {
			SEL s = @selector(_scrollPhase);
			if([event respondsToSelector:s]) {
				int (*imp)(id,SEL) = (int(*)(id,SEL))[event methodForSelector:s];
				phase = imp(event, s);
			}
		}
		
		switch(phase) {
			case ScrollPhaseNormal: {
				if(_scrollViewFlags.ignoreNextScrollPhaseNormal_10_7) {
					_scrollViewFlags.ignoreNextScrollPhaseNormal_10_7 = 0;
					return;
				}
				
				// in case we are in background, didn't get a beginGesture
				_throw.throwing = 0;
				_scrollViewFlags.didChangeContentInset = 0;
				
				[self _stopDisplayLink];
				CGEventRef cgEvent = [event CGEvent];
				const int64_t isContinuous = CGEventGetIntegerValueField(cgEvent, kCGScrollWheelEventIsContinuous);

				double dx = 0.0;
				double dy = 0.0;
				
				if(isContinuous) {
				  if(_scrollViewFlags.alwaysBounceHorizontal || [self _horizontalScrollKnobNeededForContentSize:self.contentSize])
            dx = CGEventGetDoubleValueField(cgEvent, kCGScrollWheelEventPointDeltaAxis2);
				  if(_scrollViewFlags.alwaysBounceVertical || [self _verticalScrollKnobNeededForContentSize:self.contentSize])
				    dy = CGEventGetDoubleValueField(cgEvent, kCGScrollWheelEventPointDeltaAxis1);
				} else {
					CGEventSourceRef source = CGEventCreateSourceFromEvent(cgEvent);
					if(source) {
						const double pixelsPerLine = CGEventSourceGetPixelsPerLine(source);
						if(_scrollViewFlags.alwaysBounceHorizontal || [self _horizontalScrollKnobNeededForContentSize:self.contentSize])
              dx = CGEventGetDoubleValueField(cgEvent, kCGScrollWheelEventFixedPtDeltaAxis2) * pixelsPerLine;
            if(_scrollViewFlags.alwaysBounceVertical || [self _verticalScrollKnobNeededForContentSize:self.contentSize])
              dy = CGEventGetDoubleValueField(cgEvent, kCGScrollWheelEventFixedPtDeltaAxis1) * pixelsPerLine;
						CFRelease(source);
					} else {
						NSLog(@"Critical: NULL source from CGEventCreateSourceFromEvent");
					}
				}
				
				if(MAX(fabsf(dx), fabsf(dy)) > 0.00001) { // ignore 0.0, 0.0
					_lastScroll.dx = dx;
					_lastScroll.dy = dy;
					_lastScroll.t = CFAbsoluteTimeGetCurrent();
				}
				
				CGPoint o = _unroundedContentOffset;
				
				if(!_pull.xPulling) o.x = o.x + dx;
				if(!_pull.yPulling) o.y = o.y - dy;
				
				BOOL xPulling = FALSE;
				BOOL yPulling = FALSE;
				{
					CGPoint pull = o;
					pull.x += ((_pull.xPulling) ? _pull.x : 0);
					pull.y += ((_pull.yPulling) ? _pull.y : 0);
					CGPoint fixedOffset = [self _fixProposedContentOffset:pull];
					o.x = fixedOffset.x;
					o.y = fixedOffset.y;
					xPulling = fixedOffset.x != pull.x;
					yPulling = fixedOffset.y != pull.y;
				}
				
				if(_scrollViewFlags.gestureBegan){
          float maxManualPull = 30.0;
          
					if(_pull.xPulling){
						CGFloat xCounter = pow(M_E, -1.0 / maxManualPull * fabsf(_pull.x));
						// don't counter on un-pull
						if(signbit(_pull.x) != signbit(dx))
							xCounter = 1;
						// update x-axis pulling
						if(xPulling)
							_pull.x += dx * xCounter;
					}else if(xPulling){
            _pull.x = dx;
					}
					
					if(_pull.yPulling){
						CGFloat yCounter = pow(M_E, -1.0 / maxManualPull * fabsf(_pull.y));
						// don't counter on un-pull
						if(signbit(_pull.y) == signbit(dy))
							yCounter = 1; // don't counter
						// update y-axis pulling
						if(yPulling)
							_pull.y -= dy * yCounter;
					}else if(yPulling){
            _pull.y = -dy;
					}
					
          _pull.xPulling = xPulling;
          _pull.yPulling = yPulling;
				}
				
				[self setContentOffset:o];
				break;
			}
			case ScrollPhaseThrowingBegan: {
				[self _startThrow];
				break;
			}
			case ScrollPhaseThrowing: {
				break;
			}
			case ScrollPhaseThrowingEnded: {
				if(_scrollViewFlags.animationMode == AnimationModeThrow) { // otherwise we may have started a scrollToTop:animated:, don't want to stop that)
					if(_bounce.bouncing) {
						// ignore - let the bounce finish (_updateBounce will kill the timer when it's ready)
					} else {
						[self _stopDisplayLink];
					}
				}
				break;
			}
		}
	}
}

-(void)mouseDown:(NSEvent *)event onSubview:(TUIView *)subview {
  if(subview == _verticalScrollKnob || subview == _horizontalScrollKnob){
    _scrollViewFlags.mouseDownInScrollKnob = TRUE;
    [self _updateScrollKnobsAnimated:TRUE];
  }
	
	[super mouseDown:event onSubview:subview];
}

-(void)mouseUp:(NSEvent *)event fromSubview:(TUIView *)subview {
  if(subview == _verticalScrollKnob || subview == _horizontalScrollKnob){
    _scrollViewFlags.mouseDownInScrollKnob = FALSE;
    [self _updateScrollKnobsAnimated:TRUE];
      if (_scrollViewFlags.delegateScrollViewDidEndScroll) {
          [_delegate scrollViewDidEndScroll:self];
      }
  }
	
	[super mouseUp:event fromSubview:subview];
}

-(void)mouseEntered:(NSEvent *)event onSubview:(TUIView *)subview {
  [super mouseEntered:event onSubview:subview];
  if(!_scrollViewFlags.mouseInside){
    _scrollViewFlags.mouseInside = TRUE;
    [self _updateScrollKnobsAnimated:TRUE];
  }
}

-(void)mouseExited:(NSEvent *)event fromSubview:(TUIView *)subview {
  [super mouseExited:event fromSubview:subview];
  CGPoint location = [self localPointForEvent:event];
  CGRect visible = [self visibleRect];
  if(_scrollViewFlags.mouseInside && ![self pointInside:CGPointMake(location.x, location.y + visible.origin.y) withEvent:event]){
    _scrollViewFlags.mouseInside = FALSE;
    [self _updateScrollKnobsAnimated:TRUE];
  }
}

- (BOOL)performKeyAction:(NSEvent *)event
{
	switch([[event charactersIgnoringModifiers] characterAtIndex:0]) {
		case 63276: // page up
			[self pageUp:nil];
			return YES;
		case 63277: // page down
			[self pageDown:nil];
			return YES;
		case 63273: // home
			[self scrollToTopAnimated:YES];
			return YES;
		case 63275: // end
			[self scrollToBottomAnimated:YES];
			return YES;
		case 32: // spacebar
			if([NSEvent modifierFlags] & NSShiftKeyMask)
				[self pageUp:nil];
			else
				[self pageDown:nil];
			return YES;
	}
	return NO;
}

#pragma mark - Zooming

//- (BOOL)pointInside:(CGPoint)point withEvent:(id)event
//{
//    CGRect bounds = self.frame;
//    bounds.origin = CGPointZero;
//    return CGRectContainsPoint(bounds, point);
//}

- (TUIView *)_zoomingView
{
    return (_scrollViewFlags.delegateViewForZoomingInScrollView) ? [_delegate viewForZoomingInScrollView:self] : nil;
}

- (float)zoomScale
{
    TUIView * zoomingView = [self _zoomingView];
    
    return zoomingView? zoomingView.transform.a : 1.f;
}

- (void)zoomToPoint:(CGPoint)zoomPoint scale:(float)scale animated:(BOOL)animated confined:(BOOL)confined completion:(void (^)(BOOL finished))completion
{
    TUIView *zoomingView = [self _zoomingView];
    
    if (self.zoomScale <= 0.0f){
        return;
    }
    
    if (zoomingView && self.zoomScale != scale) {
        
        void (^updating)(void) = ^(void) {
            
            // cache contentOffset, we don't want any side effects which changes this value
            CGPoint contentOffset = self.contentOffset;
            
            CGAffineTransform newTransform = CGAffineTransformScale(zoomingView.transform, scale, scale);
            [zoomingView setTransform:newTransform];
            
            CGSize size = zoomingView.frame.size;
            zoomingView.layer.position = CGPointMake(size.width/2.f, size.height/2.f);
            self.contentSize = size;
            
            CGPoint scaledContentOffset = CGPointMake(-zoomPoint.x*scale + (zoomPoint.x + contentOffset.x), -zoomPoint.y*scale + (zoomPoint.y + contentOffset.y));
            
            if (confined) {
                scaledContentOffset = [self _fixProposedContentOffset:scaledContentOffset];
            }
            
            if (!CGPointEqualToPoint(scaledContentOffset, self.contentOffset)) {
                [self _setContentOffset:scaledContentOffset];
            }
        };
        
        if (animated) {
            [TUIView animateWithDuration:TUIScrollViewAnimationDuration delay:0 curve:TUIViewAnimationCurveEaseOut animations:updating completion:completion];
        } else {
            updating();
            if (completion) {
                completion(YES);
            }
        }
    }
}

- (void)setZoomScale:(float)scale animated:(BOOL)animated
{
    TUIView *zoomingView = [self _zoomingView];
    scale = MIN(MAX(scale, _minimumZoomScale), _maximumZoomScale);
    
    if (zoomingView && self.zoomScale != scale) {
        CGPoint zoomPoint = CGPointMake(self.contentOffset.x + self.bounds.size.width * 0.5, self.contentOffset.y + self.bounds.size.height * 0.5);
        [self zoomToPoint:zoomPoint scale:scale/self.zoomScale animated:animated confined:YES  completion:NULL];
    }
}

- (void)setZoomScale:(float)zoomScale
{
    [self setZoomScale:zoomScale animated:NO];
}

- (BOOL)gestureRecognizerShouldBegin:(TUIGestureRecognizer *)gestureRecognizer
{
    return [self _zoomingView] != nil && self.maximumZoomScale > self.minimumZoomScale;
}

- (void)pinchGestureRecognized:(TUIPinchGestureRecognizer *)gestureRecognizer
{
    TUIGestureRecognizerState state = gestureRecognizer.state;
    
    if(state == TUIGestureRecognizerStateEnded) {
        _lastScale = 1.0;
        self.zooming = NO;
        // NSLog(@"reset to 1.0");
        
        BOOL didConfineOffset = NO;
        if (self.bouncesZoom && !self.zoomBouncing) {
            // perform bounces zoom animation
            CGFloat scale = MIN(MAX(self.zoomScale, self.minimumZoomScale), self.maximumZoomScale);
            if (scale != self.zoomScale && self.zoomScale > 0.0f){
                self.zoomBouncing = YES;
                CGFloat relScale = scale / self.zoomScale;
                // TODO: should fire willDecelerate?
                [self zoomToPoint:_lastZoomPoint
                            scale:relScale
                         animated:YES
                         confined:YES
                       completion:^(BOOL finished) {
                           self.zoomBouncing = NO;
                       }];
                didConfineOffset = YES;
            }
        }

        return;
    }

    self.zooming = YES; // user begins zooming
    self.zoomBouncing = NO;
    
    CGFloat scaleDiff = _lastScale - [gestureRecognizer scale];
    CGFloat scale = 1.0 - scaleDiff;
    CGFloat absScale = self.zoomScale*scale;
    
    if (absScale > self.maximumZoomScale || absScale < self.minimumZoomScale) {
        if (self.bouncesZoom) {
            CGFloat damping = MAX(absScale/self.maximumZoomScale, self.minimumZoomScale/absScale);
            NSAssert(damping >= 1.0f, @"");
            scaleDiff /= (10.0f*damping); //add some damping
            scale = 1.0f - scaleDiff;
        }else{
            if (self.zoomScale > 0) {
                absScale = MIN(self.maximumZoomScale, MAX(self.minimumZoomScale, absScale));
                scale = absScale/self.zoomScale;
            }
            
        }
    }
    
    CGPoint zoomPoint = [gestureRecognizer locationInView:self];
    zoomPoint.x += self.contentOffset.x;
    zoomPoint.y += self.contentOffset.y;
    
    _lastScale = [gestureRecognizer scale];
    _lastZoomPoint = zoomPoint;
    
    [self zoomToPoint:zoomPoint scale:scale animated:NO confined:NO completion:nil];
}

@end
