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

#import "TUIResponder.h"
#import "CoreText+Additions.h"
#import "TUITextLayout.h"

@class TUIColor;
@class TUIFont;
@class TUIView;
@class TUITextAttachment;
@protocol ABActiveTextRange;
@protocol TUITextRendererDelegate;
@protocol TUITextLayoutDelegate;

typedef enum {
	TUITextSelectionAffinityCharacter = 0,
	TUITextSelectionAffinityWord = 1,
	TUITextSelectionAffinityLine = 2,
	TUITextSelectionAffinityParagraph = 3,
} TUITextSelectionAffinity;

typedef enum {
	TUITextVerticalAlignmentTop = 0,
	// Note that TUITextVerticalAlignmentMiddle and TUITextVerticalAlignmentBottom both have a performance hit because they have to create the CTFrame twice: once to find its height and then again to shift it to match the alignment and height.
	// Also note that text selection doesn't work properly with anything but TUITextVerticalAlignmentTop.
	TUITextVerticalAlignmentMiddle,
	TUITextVerticalAlignmentBottom,
} TUITextVerticalAlignment;

@protocol TUITextRendererDelegate;

@interface TUITextRenderer : TUIResponder
{
	CFIndex _selectionStart;
	CFIndex _selectionEnd;
	TUITextSelectionAffinity _selectionAffinity;
	
	id<ABActiveTextRange> hitRange;
    TUITextAttachment * hitAttachment;
	
	CGSize shadowOffset;
	CGFloat shadowBlur;
	TUIColor *shadowColor;
	
	NSMutableDictionary *lineRects;
	
	TUITextVerticalAlignment verticalAlignment;
	
	struct {
		unsigned int drawMaskDragSelection:1;
		unsigned int backgroundDrawingEnabled:1;
		unsigned int preDrawBlocksEnabled:1;		
	} _flags;
}

@property (nonatomic, strong) NSAttributedString *attributedString;

@property (nonatomic, strong) TUITextLayout * textLayout;

@property (nonatomic, assign) CGRect frame;

@property (nonatomic, weak) id<TUITextRendererDelegate> renderDelegate;
@property (nonatomic, weak) id<TUITextLayoutDelegate> layoutDelegate;

@property (nonatomic, assign) CGSize shadowOffset;
@property (nonatomic, assign) CGFloat shadowBlur;
@property (nonatomic, strong) TUIColor *shadowColor; // default = nil for no shadow

@property (nonatomic, assign) TUITextVerticalAlignment verticalAlignment;

// These are both advanced features that carry with them a potential performance hit.
@property (nonatomic, assign) BOOL backgroundDrawingEnabled; // default = NO
@property (nonatomic, assign) BOOL preDrawBlocksEnabled; // default = NO

@property (nonatomic, assign, readonly) CGPoint drawingOrigin;

- (void)draw;
- (void)drawInContext:(CGContextRef)context;
- (void)drawInContext:(CGContextRef)context threadSafely:(BOOL)threadSafe;

- (CGSize)sizeConstrainedToWidth:(CGFloat)width;
- (CGSize)sizeConstrainedToWidth:(CGFloat)width numberOfLines:(NSUInteger)numberOfLines;

- (NSRange)selectedRange;
- (void)setSelection:(NSRange)selection;
- (NSString *)selectedString;

// Draw the selection for the given rects. You probably shouldn't ever call this directly but it is exposed to allow for overriding. This will only get called if the selection is not empty and the selected text isn't being dragged.
// Note that at the point at which this is called, the selection color has already been set.
//
// rects - an array of rects for the current selection
// count - the number of rects in the `rects` array
- (void)drawSelectionWithRects:(CGRect *)rects count:(CFIndex)count;

@property (nonatomic, strong) id<ABActiveTextRange> hitRange;
@property (nonatomic, strong) TUITextAttachment * hitAttachment;

@property (nonatomic, assign) CGFloat baselineAscent;
@property (nonatomic, assign) CGFloat baselineDescent;
@property (nonatomic, assign) CGFloat baselineLeading;

- (void)renderAttachment:(TUITextAttachment *)attachment highlighted:(BOOL)highlighted inContext:(CGContextRef)ctx;

- (NSColor *)selectedTextBackgroundColor;

@end

@protocol TUITextRendererDelegate <NSObject>

@optional

/**
 *  TextAttachment 渲染的回调方法，delegate 可以通过此方法定义 Attachment 的样式，具体显示的方式可以是绘制到 context 或者添加一个自定义 View
 *
 *  @param textRenderer 执行文字渲染的 TextRenderer
 *  @param attachment   需要渲染的 TextAttachment
 *  @param frame        建议渲染到的 frame
 *  @param context      当前的 CGContext
 */
- (void)textRenderer:(TUITextRenderer *)textRenderer renderTextAttachment:(TUITextAttachment *)attachment highlighted:(BOOL)highlighted inContext:(CGContextRef)ctx;

@end

@interface TUITextRenderer (Coordinates)

/**
 *  将坐标点从文字布局中转换到 TextRenderer 的绘制区域中
 *
 *  @param point 需要转换的坐标点
 *
 *  @return 转换过的坐标点
 */
- (CGPoint)convertPointFromLayout:(CGPoint)point;

/**
 *  将坐标点从 TextRenderer 的绘制区域转换到文字布局中
 *
 *  @param point 需要转换的坐标点
 *
 *  @return 转换过的坐标点
 */
- (CGPoint)convertPointToLayout:(CGPoint)point;

/**
 *  将一个 rect 从文字布局中转换到 TextRenderer 的绘制区域中
 *
 *  @param rect 需要转换的 rect
 *
 *  @return 转换后的 rect
 */
- (CGRect)convertRectFromLayout:(CGRect)rect;

/**
 *  将一个 rect 从 TextRenderer 的绘制区域转换到文字布局中
 *
 *  @param rect 需要转换的 rect
 *
 *  @return 转换后的 rect
 */
- (CGRect)convertRectToLayout:(CGRect)rect;

@end

#import "TUITextRenderer+Event.h"
#import "TUITextRenderer+LayoutResult.h"

NS_INLINE NSRange ABNSRangeFromCFRange(CFRange r) { return NSMakeRange(r.location, r.length); }
NS_INLINE CFRange ABCFRangeFromNSRange(NSRange r) { return CFRangeMake(r.location, r.length); }
