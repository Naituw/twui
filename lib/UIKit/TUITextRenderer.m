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

#import "TUITextRenderer.h"
#import "TUITextRenderer_Private.h"
#import "ABActiveRange.h"
#import "TUIAttributedString.h"
#import "TUICGAdditions.h"
#import "TUIColor.h"
#import "TUIFont.h"
#import "TUIStringDrawing.h"
#import "TUITextRenderer+Event.h"
#import "TUIView.h"
#import "TUITextLayout_Private.h"
#import "TUITextRenderer+Debug.h"
#import "TUITextLayoutLine_Private.h"
#import "TUITextComposedSequence.h"

@interface TUITextRenderer ()

@property (nonatomic, assign) CGPoint drawingOrigin;

@end

@implementation TUITextRenderer

@synthesize hitRange;
@synthesize hitAttachment;
@synthesize shadowColor;
@synthesize shadowOffset;
@synthesize shadowBlur;
@synthesize verticalAlignment;

- (CFIndex)_clampToValidRange:(CFIndex)index
{
	if(index < 0) return 0;
	CFIndex max = [self.attributedString length] - 1;
	if(index > max) return max;
	return index;
}

- (NSRange)_wordRangeAtIndex:(CFIndex)index
{
	return [self.attributedString doubleClickAtIndex:[self _clampToValidRange:index]];
}

- (NSRange)_lineRangeAtIndex:(CFIndex)index
{
	return [[self.attributedString string] lineRangeForRange:NSMakeRange(index, 0)];
}

- (NSRange)_paragraphRangeAtIndex:(CFIndex)index
{
	return [[self.attributedString string] paragraphRangeForRange:NSMakeRange(index, 0)];
}

- (NSRange)_selectedRange
{
	CFIndex first, last;
	if(_selectionStart <= _selectionEnd) {
		first = _selectionStart;
		last = _selectionEnd;
	} else {
		first = _selectionEnd;
		last = _selectionStart;
	}
	
	if(_selectionAffinity != TUITextSelectionAffinityCharacter) {
		NSRange fr = {0,0};
		NSRange lr = {0,0};
		
		switch(_selectionAffinity) {
			case TUITextSelectionAffinityCharacter:
				// do nothing
				break;
			case TUITextSelectionAffinityWord:
				fr = [self _wordRangeAtIndex:first];
				lr = [self _wordRangeAtIndex:last];
				break;
			case TUITextSelectionAffinityLine:
				fr = [self _lineRangeAtIndex:first];
				lr = [self _lineRangeAtIndex:last];
				break;
			case TUITextSelectionAffinityParagraph:
				fr = [self _paragraphRangeAtIndex:first];
				lr = [self _paragraphRangeAtIndex:last];
				break;
		}
		
		first = fr.location;
		last = lr.location + lr.length;
	}

	NSRange range = NSMakeRange(first, last - first);
    
    if (self.attributedString.length) {
        range = [self.attributedString tui_effectiveRangeByRoundingToComposedSequencesForRange:range];
    }
    
    return range;
}

- (NSRange)selectedRange
{
	return [self _selectedRange];
}

- (void)setSelection:(NSRange)selection
{
	_selectionAffinity = TUITextSelectionAffinityCharacter;
	_selectionStart = selection.location;
	_selectionEnd = selection.location + selection.length;
	[self.eventDelegateContextView setNeedsDisplay];
}

- (NSString *)selectedString
{
    NSAttributedString * attributedSubstring = [self.attributedString attributedSubstringFromRange:[self selectedRange]];

    return [attributedSubstring tui_stringByReplaceTextComposedSequencesForCopy];    
}

- (void)setRenderDelegate:(id<TUITextRendererDelegate>)renderDelegate
{
    if (_renderDelegate != renderDelegate) {
        _renderDelegate = renderDelegate;
        
        _renderDelegateHas.placeAttachment = [renderDelegate respondsToSelector:@selector(textRenderer:renderTextAttachment:highlighted:inContext:)];
    }
}

- (id<TUITextLayoutDelegate>)layoutDelegate
{
    return self.textLayout.delegate;
}

- (void)setLayoutDelegate:(id<TUITextLayoutDelegate>)layoutDelegate
{
    self.textLayout.delegate = layoutDelegate;
}

- (void)draw
{
	[self drawInContext:TUIGraphicsGetCurrentContext()];
}

- (void)drawInContext:(CGContextRef)context
{
    [self drawInContext:context threadSafely:NO];
}

- (void)drawInContext:(CGContextRef)context threadSafely:(BOOL)threadSafe;
{
    if (!context) {
        return;
    }
    
    TUITextLayout * layout = self.textLayout;
    TUITextLayoutFrame * layoutFrame = layout.layoutFrame;
    NSAttributedString * attributedString = layout.attributedString;
    
    if (!layoutFrame) {
        return;
    }

    CGPoint drawingOffset = CGPointZero;
    
    BOOL debugMode = NO;
    
    if (debugMode) {
        [self debugModeDrawLineFramesWithLayoutFrame:layoutFrame context:context offset:drawingOffset];
    }
    
    if (self.hitRange && !_flags.drawMaskDragSelection) {
        CGContextSaveGState(context);
        
        [layoutFrame enumerateEnclosingRectsForCharacterRange:self.hitRange.rangeValue usingBlock:^(CGRect rect, NSRange characterRange, BOOL *stop) {
            rect = [self convertRectFromLayout:rect];
            rect.origin.x += drawingOffset.x;
            rect.origin.y += drawingOffset.y;
            [self drawHighlightedBackgroundForActiveRange:self.hitRange rect:rect context:context];
        }];
        
        CGContextRestoreGState(context);
    }
    
    NSRange selectedRange = [self _selectedRange];
    
    if (selectedRange.length > 0) {
        [[self selectedTextBackgroundColor] set];
        // draw (or mask) selection
        
        if (_flags.drawMaskDragSelection) {
            NSMutableArray * rectValues = [NSMutableArray array];
            [layoutFrame enumerateSelectionRectsForCharacterRange:selectedRange usingBlock:^(CGRect rect, NSRange characterRange, BOOL *stop) {
                [rectValues addObject:[NSValue valueWithRect:(NSRect)[self convertRectFromLayout:rect]]];
            }];
            NSUInteger rectCount = rectValues.count;
            CGRect rects[rectCount];
            for (NSUInteger idx = 0; idx < rectCount; idx++) {
                NSValue * value = rectValues[idx];
                CGRect rect = (CGRect)[value rectValue];
                rects[idx] = rect;
            }
            CGContextClipToRects(context, rects, rectCount);
        } else {
            [layoutFrame enumerateSelectionRectsForCharacterRange:selectedRange usingBlock:^(CGRect rect, NSRange characterRange, BOOL *stop) {
                rect = [self convertRectFromLayout:rect];
                rect = CGRectIntegral(rect);
                if (rect.size.width > 1) {
                    CGContextFillRect(context, rect);
                }
            }];
        }
    }
    
    {
        id<ABActiveTextRange> highlighter = self.highlightedRange;
        if (highlighter) {
            CGFloat scale = self.eventDelegateContextView.layer.contentsScale;
            [layoutFrame enumerateSelectionRectsForCharacterRange:highlighter.rangeValue usingBlock:^(CGRect rect, NSRange characterRange, BOOL *stop) {
                rect = [self convertRectFromLayout:rect];
                rect = CGRectIntegral(rect);
                if (rect.size.width > 1) {
                    CGContextSaveGState(context);
                    [[TUIColor colorWithWhite:0.0 alpha:0.16] set];
                    CGContextFillRect(context, CGRectInset(rect, -1.0/scale, -1.0/scale));
                    CGContextSetShadowWithColor(context, CGSizeMake(0, -2), 7, [TUIColor colorWithWhite:0.0 alpha:0.2].CGColor);
                    [[NSColor colorWithCalibratedRed:254.0/255 green:249.0/255 blue:0 alpha:1.0] setFill];
                    CGContextFillRect(context, rect);
                    CGContextRestoreGState(context);
                }
            }];
        }
    }
    
    if (self.shadowColor) {
        CGContextSetShadowWithColor(context, self.shadowOffset, self.shadowBlur, self.shadowColor.CGColor);
    }

    CGContextSaveGState(context);

    for (TUITextLayoutLine * line in layoutFrame.lineFragments) {
        
        CTLineRef lineRef = line.lineRef;
        CGPoint lineOrigin = line.baselineOrigin;
        lineOrigin = [layout convertPointToCoreText:lineOrigin]; // since the context ctm is filpped, we should also convert origin here
        lineOrigin = [self convertPointFromLayout:lineOrigin];
        
        lineOrigin.x += drawingOffset.x;
        lineOrigin.y += drawingOffset.y;
        
        CGContextSetTextPosition(context, lineOrigin.x, lineOrigin.y);
        
        CTLineDraw(lineRef, context);
    }
    
    CGContextRestoreGState(context);

    [self drawAttachmentsWithAttributedString:attributedString layoutFrame:layoutFrame context:context];
    
//    if (_attributedString)
//    {
//        CTFrameRef f = NULL;
//        
//        if (threadSafe)
//        {
//            f = [self newCTFrameWithAttributedString:_attributedString];
//        }
//        else
//        {
//            f = [self ctFrame];
//            CFRetain(f);
//        }
//        
//        if(f)
//        {
//            CGPathRef path = CTFrameGetPath(f);
//            CGRect textFrame = CGPathGetPathBoundingBox(path);
//            
//            CGContextSaveGState(context);
//            
//            if(hitRange && !_flags.drawMaskDragSelection) {
//                // draw highlight
//                CGContextSaveGState(context);
//                
//                NSRange _r = [hitRange rangeValue];
//                CFRange r = {_r.location, _r.length};
//                CFIndex nRects = 10;
//                CGRect rects[nRects];
//                AB_CTFrameGetRectsForRange(f, r, rects, &nRects);
//                for(int i = 0; i < nRects; ++i) {
//                    CGRect rect = rects[i];
//                    rect = CGRectInset(rect, -2, -1);
//                    rect.size.height -= 1;
//                    rect = CGRectIntegral(rect);
//                    TUIColor *color = [TUIColor colorWithWhite:1.0 alpha:1.0];
//                    [color set];
//                    CGContextSetShadowWithColor(context, CGSizeMake(0, 0), 8, color.CGColor);
//                    CGContextFillRoundRect(context, rect, 10);
//                }
//                
//                CGContextRestoreGState(context);
//            }
//            
//            CFRange selectedRange = [self _selectedRange];
//            
//            if(selectedRange.length > 0) {
//                [[self selectedTextBackgroundColor] set];
//                // draw (or mask) selection
//                CFIndex rectCount = 100;
//                CGRect rects[rectCount];
//                AB_CTFrameGetRectsForRangeWithAggregationType(f, selectedRange, AB_CTLineRectAggregationTypeInlineContinuous, rects, &rectCount);
//                if(_flags.drawMaskDragSelection) {
//                    CGContextClipToRects(context, rects, rectCount);
//                } else {
//                    for(CFIndex i = 0; i < rectCount; ++i) {
//                        CGRect r = rects[i];
//                        r = CGRectIntegral(r);
//                        if(r.size.width > 1)
//                            CGContextFillRect(context, r);
//                    }
//                }
//            }
//
//            CGContextSetTextMatrix(context, CGAffineTransformIdentity);
//            
//            if(shadowColor)
//                CGContextSetShadowWithColor(context, shadowOffset, shadowBlur, shadowColor.CGColor);
//            
//            
//            NSArray *lines = (NSArray *)CTFrameGetLines(f);
//            NSInteger n = [lines count];
//            CGPoint lineOrigins[n];
//            CTFrameGetLineOrigins(f, CFRangeMake(0, n), lineOrigins);
//            CGFloat baseDescent = self.baselineDescent;
//            CGFloat baseAscent = self.baselineAscent;
//            CGFloat baseLeading = self.baselineLeading;
//            CGFloat ascent, descent, leading, originalLineWidth;
//            CGFloat lineOriginDeltaY = 0;
//            
//            for(int i = 0; i < n; i++)
//            {
//                CTLineRef line = (__bridge CTLineRef)[lines objectAtIndex:i];
//                CGPoint lineOrigin = lineOrigins[i];
//                originalLineWidth = CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
//                if (baseDescent == NSNotFound) baseDescent = descent;
//                if (baseAscent == NSNotFound) baseAscent = ascent;
//                if (baseLeading == NSNotFound) baseLeading = leading;
//                
//                if (n == 1)
//                {
//                    lineOrigin.y += (descent - baseDescent);
//                    lineOrigin.y -= (ascent - baseAscent);
//                    // lineOrigin.y += (leading - baseLeading);
//                }
//                else
//                {
//                    lineOrigin.y -= (descent - baseDescent);
//                }
//                
//                lineOrigin.y -= lineOriginDeltaY;
//                lineOrigins[i] = lineOrigin;
//                
//                CGContextSetTextPosition(context, textFrame.origin.x + lineOrigin.x, textFrame.origin.y + lineOrigin.y);
//
//                CTLineDraw(line, context);
//            }
//            
//            CFRelease(f);
//            
//            CGPoint * origins = lineOrigins;
//            [_attributedString tui_enumerateTextAttachments:^(TUITextAttachment * value, NSRange range, BOOL *stop) {
//                CFIndex rectCount = 100;
//                CGRect rects[rectCount];
//                AB_CTLinesGetRectsForRangeWithAggregationType(lines, origins, textFrame, CFRangeMake(range.location, range.length), AB_CTLineRectAggregationTypeInline, rects, &rectCount);
//                if (rectCount > 0) {
//                    CGRect placeholderRect = rects[0];
//                    value.derivedFrame = ABIntegralRectWithSizeCenteredInRect(value.contentSize, placeholderRect);
//                    [self renderAttachment:value highlighted:(value == hitAttachment) inContext:context];
//                }
//            }];
//            
//            CGContextRestoreGState(context);
//        }
//    }
//    
//    _attributedString = nil;
}

- (void)drawSelectionWithRects:(CGRect *)rects count:(CFIndex)count {
	CGContextRef context = TUIGraphicsGetCurrentContext();
	for(CFIndex i = 0; i < count; ++i) {
		CGRect r = rects[i];
		r = CGRectIntegral(r);
		if(r.size.width > 1)
			CGContextFillRect(context, r);
	}
}

- (CGSize)sizeConstrainedToWidth:(CGFloat)width
{
	if(self.attributedString) {
		CGRect oldFrame = self.frame;
		self.frame = CGRectMake(0.0f, 0.0f, width, 100000.0f);

		CGSize size = self.textLayout.layoutSize;
		
		self.frame = oldFrame;
		
		return size;
	}
	return CGSizeZero;
}

- (CGSize)sizeConstrainedToWidth:(CGFloat)width numberOfLines:(NSUInteger)numberOfLines
{
	NSMutableAttributedString *fake = [self.attributedString mutableCopy];
	[fake replaceCharactersInRange:NSMakeRange(0, [fake length]) withString:@"M"];
	CGFloat singleLineHeight = [fake ab_sizeConstrainedToWidth:width].height;
	CGFloat maxHeight = singleLineHeight * numberOfLines;
	CGSize size = [self sizeConstrainedToWidth:width];
	return CGSizeMake(size.width, MIN(maxHeight, size.height));
}

- (void)setAttributedString:(NSAttributedString *)a
{
    self.textLayout.attributedString = a;
}

- (NSAttributedString *)attributedString
{
    return self.textLayout.attributedString;
}

- (TUITextLayout *)textLayout
{
    if (!_textLayout) {
        _textLayout = [[TUITextLayout alloc] init];
    }
    return _textLayout;
}

- (CGRect)frame
{
    CGRect f = CGRectZero;
    f.size = self.textLayout.size;
    f.origin = self.drawingOrigin;
    return f;
}

- (void)setFrame:(CGRect)frame
{
    self.drawingOrigin = frame.origin;
    self.textLayout.size = frame.size;
}

- (BOOL)backgroundDrawingEnabled
{
	return _flags.backgroundDrawingEnabled;
}

- (void)setBackgroundDrawingEnabled:(BOOL)enabled
{
	_flags.backgroundDrawingEnabled = enabled;
}

- (BOOL)preDrawBlocksEnabled
{
	return _flags.preDrawBlocksEnabled;
}

- (void)setPreDrawBlocksEnabled:(BOOL)enabled
{
	_flags.preDrawBlocksEnabled = enabled;
}

- (void)setVerticalAlignment:(TUITextVerticalAlignment)alignment
{
	if (verticalAlignment == alignment) return;
	
	verticalAlignment = alignment;
}

- (void)setNeedsDisplay
{
	[self.eventDelegateContextView setNeedsDisplay];
}

- (void)drawAttachmentsWithAttributedString:(NSAttributedString *)attributedString layoutFrame:(TUITextLayoutFrame *)layoutFrame context:(CGContextRef)ctx
{
    [attributedString tui_enumerateTextAttachments:^(TUITextAttachment * value, NSRange range, BOOL *stop) {
        NSUInteger lineIndex = [layoutFrame lineFragmentIndexForCharacterAtIndex:range.location];
        TUIFontMetrics lineMetrics = [self.textLayout lineFragmentMetricsForLineAtIndex:lineIndex effectiveRange:NULL];
        [layoutFrame enumerateEnclosingRectsForCharacterRange:range usingBlock:^(CGRect rect, NSRange characterRange, BOOL *stop) {
            rect = [self convertRectFromLayout:rect];
            rect.origin.y = CGRectGetMinY(rect) + lineMetrics.descent + lineMetrics.leading - value.descentForLayout;
            rect.size = value.contentSize;
            value.derivedFrame = rect;
            [self renderAttachment:value highlighted:(value == hitAttachment) inContext:ctx];
            *stop = YES;
        }];
    }];
}

- (void)renderAttachment:(TUITextAttachment *)attachment highlighted:(BOOL)highlighted inContext:(CGContextRef)ctx
{
    if (_renderDelegateHas.placeAttachment) {
        [self.renderDelegate textRenderer:self renderTextAttachment:attachment highlighted:highlighted inContext:ctx];
    }
}

- (NSColor *)selectedTextBackgroundColor
{
    return [NSColor selectedTextBackgroundColor];
}

- (void)drawHighlightedBackgroundForActiveRange:(id<ABActiveTextRange>)activeRange rect:(CGRect)rect context:(CGContextRef)context
{
    rect = CGRectIntegral(rect);
    TUIColor *color = [TUIColor colorWithWhite:1.0 alpha:1.0];
    [color set];
    CGContextSetShadowWithColor(context, CGSizeMake(0, 0), 8, color.CGColor);
    CGContextFillRoundRect(context, rect, 10);
}

@end

@implementation TUITextRenderer (Coordinates)

- (CGPoint)convertPointFromLayout:(CGPoint)point
{
    point.x += _drawingOrigin.x;
    point.y += _drawingOrigin.y;
    
    if (verticalAlignment != TUITextVerticalAlignmentTop) {
        TUITextLayout * layout = self.textLayout;
        CGFloat heightDelta = layout.size.height - layout.layoutSize.height;
        if (verticalAlignment == TUITextVerticalAlignmentMiddle) {
            point.y -= heightDelta / 2;
        } else {
            point.y -= heightDelta;
        }
    }
    
    return point;
}

- (CGPoint)convertPointToLayout:(CGPoint)point
{
    point.x -= _drawingOrigin.x;
    point.y -= _drawingOrigin.y;
    
    if (verticalAlignment != TUITextVerticalAlignmentTop) {
        TUITextLayout * layout = self.textLayout;
        CGFloat heightDelta = layout.size.height - layout.layoutSize.height;
        if (verticalAlignment == TUITextVerticalAlignmentMiddle) {
            point.y += heightDelta / 2;
        } else {
            point.y += heightDelta;
        }
    }
    
    return point;
}

- (CGRect)convertRectFromLayout:(CGRect)rect
{
    if (CGRectIsNull(rect)) {
        return rect;
    }
    
    rect.origin = [self convertPointFromLayout:rect.origin];
    return rect;
}

- (CGRect)convertRectToLayout:(CGRect)rect
{
    if (CGRectIsNull(rect)) {
        return rect;
    }
    
    rect.origin = [self convertPointToLayout:rect.origin];
    return rect;
}

@end

