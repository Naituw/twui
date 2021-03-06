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

#import "TUITextRenderer+Event.h"
#import "CoreText+Additions.h"
#import "TUICGAdditions.h"
#import "TUIImage.h"
#import "TUINSView.h"
#import "TUINSWindow.h"
#import "TUIView+Private.h"
#import "TUIView.h"

@interface TUITextRenderer()
- (CTFramesetterRef)ctFramesetter;
- (CTFrameRef)ctFrame;
- (CGPathRef)ctPath;
- (CFRange)_selectedRange;
@end

@implementation TUITextRenderer (Event)

+ (void)initialize
{
    static BOOL initialized = NO;
	if(!initialized) {
		initialized = YES;
		// set up Services
		[NSApp registerServicesMenuSendTypes:[NSArray arrayWithObjects:NSStringPboardType, nil] returnTypes:nil];
	}
}

- (id<TUITextRendererDelegate>)delegate
{
	return delegate;
}

- (void)setDelegate:(id<TUITextRendererDelegate>)d
{
	delegate = d;
	
    _flags.delegateTextRendererActiveRangeAtIndex = [delegate respondsToSelector:@selector(textRenderer:activeRangeAtIndex:)];
    _flags.delegateTextRendererDidClickActiveRange = [delegate respondsToSelector:@selector(textRenderer:didClickActiveRange:)];
	_flags.delegateActiveRangesForTextRenderer = [delegate respondsToSelector:@selector(activeRangesForTextRenderer:)];
    _flags.delegateRenderTextAttachment = [delegate respondsToSelector:@selector(textRenderer:renderTextAttachment:highlighted:inContext:)];
    _flags.delegateDidClickTextAttachment = [delegate respondsToSelector:@selector(textRenderer:didClickTextAttachment:)];
	_flags.delegateWillBecomeFirstResponder = [delegate respondsToSelector:@selector(textRendererWillBecomeFirstResponder:)];
	_flags.delegateDidBecomeFirstResponder = [delegate respondsToSelector:@selector(textRendererDidBecomeFirstResponder:)];
	_flags.delegateWillResignFirstResponder = [delegate respondsToSelector:@selector(textRendererWillResignFirstResponder:)];
	_flags.delegateDidResignFirstResponder = [delegate respondsToSelector:@selector(textRendererDidResignFirstResponder:)];
}

- (CGPoint)localPointForEvent:(NSEvent *)event
{
	CGPoint p = [view localPointForEvent:event];
	p.x -= frame.origin.x;
	p.y -= frame.origin.y;
	return p;
}

- (CFIndex)stringIndexForPoint:(CGPoint)p
{
	return AB_CTFrameGetStringIndexForPosition([self ctFrame], p);
}

- (CFIndex)stringIndexForEvent:(NSEvent *)event
{
	return [self stringIndexForPoint:[self localPointForEvent:event]];
}

- (id<ABActiveTextRange>)rangeInRanges:(NSArray *)ranges forStringIndex:(CFIndex)index
{
	for(id<ABActiveTextRange> rangeValue in ranges) {
		NSRange range = [rangeValue rangeValue];
		if(NSLocationInRange(index, range))
			return rangeValue;
	}
	return nil;
}

- (TUIImage *)dragImageForSelection:(NSRange)selection
{
	CGRect b = self.view.frame;
	
	_flags.drawMaskDragSelection = 1;
	TUIImage *image = TUIGraphicsDrawAsImage(b.size, ^{
		[self draw];
	});
	_flags.drawMaskDragSelection = 0;
	return image;
}

- (BOOL)beginWaitForDragInRange:(NSRange)range string:(NSString *)string
{
	CFAbsoluteTime downTime = CFAbsoluteTimeGetCurrent();
	NSEvent *nextEvent = [NSApp nextEventMatchingMask:NSAnyEventMask
											untilDate:[NSDate distantFuture]
											   inMode:NSEventTrackingRunLoopMode
											  dequeue:YES];
	CFAbsoluteTime nextEventTime = CFAbsoluteTimeGetCurrent();
	if(([nextEvent type] == NSLeftMouseDragged) && (nextEventTime > downTime + 0.11)) {
		NSPasteboard *pasteboard = [NSPasteboard pasteboardWithName:NSDragPboard];
		[pasteboard clearContents];
		[pasteboard writeObjects:[NSArray arrayWithObject:string]];
		NSRect f = [view frameInNSView];
		
		CFIndex saveStart = _selectionStart;
		CFIndex saveEnd = _selectionEnd;
		_selectionStart = range.location;
		_selectionEnd = range.location + range.length;
		TUIImage *dragImage = [self dragImageForSelection:range];
		_selectionStart = saveStart;
		_selectionEnd = saveEnd;
		
		NSImage *image = [[NSImage alloc] initWithCGImage:dragImage.CGImage size:NSZeroSize];
		
		[view.nsView dragImage:image 
							at:f.origin
						offset:NSZeroSize
						 event:nextEvent 
					pasteboard:pasteboard 
						source:self 
					 slideBack:YES];
		return YES;
	} else {
		return NO;
	}
}

- (void)mouseDown:(NSEvent *)event
{
	CGRect previousSelectionRect = [self rectForCurrentSelection];
	
	switch([event clickCount]) {
		case 4:
			_selectionAffinity = TUITextSelectionAffinityParagraph;
			break;
		case 3:
			_selectionAffinity = TUITextSelectionAffinityLine;
			break;
		case 2:
			_selectionAffinity = TUITextSelectionAffinityWord;
			break;
		default:
			_selectionAffinity = TUITextSelectionAffinityCharacter;
			break;
	}
    
	CFIndex eventIndex = [self stringIndexForEvent:event];
    CGPoint eventLocation = [view localPointForEvent:event];
    TUITextAttachment * __block hitTextAttachment = nil;
    id<ABActiveTextRange> hitActiveRange = nil;
    
    [self.attributedString tui_enumerateTextAttachments:^(TUITextAttachment *attachment, NSRange range, BOOL *stop) {
        if (attachment.userInteractionEnabled && CGRectContainsPoint(attachment.derivedFrame, eventLocation)) {
            hitTextAttachment = attachment;
            *stop = YES;
        }
    }];
    
    if (hitTextAttachment) {
        if (hitTextAttachment.userInteractionEnabled) {
            _selectionAffinity = TUITextSelectionAffinityCharacter; // don't select text when we are clicking interactable attachment
        }
        goto normal;
    }
    
    if (_flags.delegateTextRendererActiveRangeAtIndex) {
        hitActiveRange = [delegate textRenderer:self activeRangeAtIndex:eventIndex];
    } else if (_flags.delegateActiveRangesForTextRenderer) {
        NSArray * ranges = [delegate activeRangesForTextRenderer:self];
        hitActiveRange = [self rangeInRanges:ranges forStringIndex:eventIndex];
    }

	if([event clickCount] > 1)
		goto normal; // we want double-click-drag-select-by-word, not drag selected text
	
	if(hitActiveRange) {
		self.hitRange = hitActiveRange;
		[self.view redraw];
		self.hitRange = nil;
		
		NSRange r = [hitActiveRange rangeValue];
		NSString *s = [[attributedString string] substringWithRange:r];
		
		// bit of a hack
		if(hitActiveRange.rangeFlavor == ABActiveTextRangeFlavorURL) {
			if([hitActiveRange respondsToSelector:@selector(url)]) {
				NSString *urlString = [[hitActiveRange performSelector:@selector(url)] absoluteString];
				if(urlString)
					s = urlString;
			}
		}
		
		if(![self beginWaitForDragInRange:r string:s])
			goto normal;
	} else if(NSLocationInRange(eventIndex, [self selectedRange])) {
		if(![self beginWaitForDragInRange:[self selectedRange] string:[self selectedString]])
			goto normal;
	} else {
normal:
		if(([event modifierFlags] & NSShiftKeyMask) != 0) {
			CFIndex newIndex = [self stringIndexForEvent:event];
			if(newIndex < _selectionStart) {
				_selectionStart = newIndex;
			} else {
				_selectionEnd = newIndex;
			}
		} else {
			_selectionStart = [self stringIndexForEvent:event];
			_selectionEnd = _selectionStart;
		}
		
		self.hitRange = hitActiveRange;
        self.hitAttachment = hitTextAttachment;
	}
	
	CGRect totalRect = CGRectUnion(previousSelectionRect, [self rectForCurrentSelection]);
	[view setNeedsDisplayInRect:totalRect];
	if([self acceptsFirstResponder])
		[[view nsWindow] tui_makeFirstResponder:self];
}

- (void)mouseUp:(NSEvent *)event
{
	CGRect previousSelectionRect = [self rectForCurrentSelection];
	
	if(([event modifierFlags] & NSShiftKeyMask) == 0) {
		CFIndex i = [self stringIndexForEvent:event];
		_selectionEnd = i;
	}
	
	// fixup selection based on selection affinity
	BOOL flip = _selectionEnd < _selectionStart;
	CFRange trueRange = [self _selectedRange];
	_selectionStart = trueRange.location;
	_selectionEnd = _selectionStart + trueRange.length;
	if(flip) {
		// maintain anchor point, if we select with mouse, then start using keyboard to tweak
		CFIndex x = _selectionStart;
		_selectionStart = _selectionEnd;
		_selectionEnd = x;
	}
	
	_selectionAffinity = TUITextSelectionAffinityCharacter; // reset affinity
	
	CGRect totalRect = CGRectUnion(previousSelectionRect, [self rectForCurrentSelection]);
	[view setNeedsDisplayInRect:totalRect];
    
    if (self.hitRange && _flags.delegateTextRendererDidClickActiveRange) {
        [self.delegate textRenderer:self didClickActiveRange:self.hitRange];
    }
    self.hitRange = nil;
    
    if (self.hitAttachment && _flags.delegateDidClickTextAttachment) {
        [self.delegate textRenderer:self didClickTextAttachment:self.hitAttachment];
    }
    self.hitAttachment = nil;
}

- (void)mouseDragged:(NSEvent *)event
{
	CGRect previousSelectionRect = [self rectForCurrentSelection];
	
	CFIndex i = [self stringIndexForEvent:event];
	_selectionEnd = i;
	
	CGRect totalRect = CGRectUnion(previousSelectionRect, [self rectForCurrentSelection]);
	[view setNeedsDisplayInRect:totalRect];
    
    self.hitRange = nil;
    self.hitAttachment = nil;
}

- (NSMenu *)menuForEvent:(NSEvent *)event
{
    if ([self.delegate respondsToSelector:@selector(textRenderer:contextMenuForTextAttachment:event:)]) {
        CGPoint eventLocation = [view localPointForEvent:event];
        TUITextAttachment * __block hitTextAttachment = nil;
        
        [self.attributedString tui_enumerateTextAttachments:^(TUITextAttachment *attachment, NSRange range, BOOL *stop) {
            if (attachment.userInteractionEnabled && CGRectContainsPoint(attachment.derivedFrame, eventLocation)) {
                hitTextAttachment = attachment;
                *stop = YES;
            }
        }];
        
        if (hitTextAttachment) {
            NSMenu * menu = [self.delegate textRenderer:self contextMenuForTextAttachment:hitTextAttachment event:event];
            if (menu) {
                return menu;
            }
        }
    }
    return [super menuForEvent:event];
}

- (CGRect)rectForCurrentSelection {
	return [self rectForRange:[self _selectedRange]];
}

- (CGRect)rectForRange:(CFRange)range {
	CTFrameRef textFrame = [self ctFrame];
	CGRect totalRect = CGRectNull;
	if(range.length > 0) {
		CFIndex rectCount = 100;
		CGRect rects[rectCount];
		AB_CTFrameGetRectsForRangeWithAggregationType(textFrame, range, AB_CTLineRectAggregationTypeBlock, rects, &rectCount);
		
		for(CFIndex i = 0; i < rectCount; ++i) {
			CGRect rect = rects[i];
			rect = CGRectIntegral(rect);
			
			if(CGRectEqualToRect(totalRect, CGRectNull)) {
				totalRect = rect;
			} else {
				totalRect = CGRectUnion(rect, totalRect);
			}
		}
	}
	
	return totalRect;
}

- (void)resetSelection
{
	_selectionStart = 0;
	_selectionEnd = 0;
	_selectionAffinity = TUITextSelectionAffinityCharacter;
	self.hitRange = nil;
	[view setNeedsDisplay];
}

- (void)selectAll:(id)sender
{
	_selectionStart = 0;
	_selectionEnd = [[attributedString string] length];
	_selectionAffinity = TUITextSelectionAffinityCharacter;
	[view setNeedsDisplay];
}

- (void)copy:(id)sender
{
	NSString *selectedString = [self selectedString];
	if ([selectedString length] > 0) {
		[[NSPasteboard generalPasteboard] clearContents];
		[[NSPasteboard generalPasteboard] writeObjects:[NSArray arrayWithObject:selectedString]];
	} else {
		[[self nextResponder] tryToPerform:@selector(copy:) with:sender];
	}
}

- (BOOL)acceptsFirstResponder
{
	return YES;
}

- (BOOL)becomeFirstResponder
{
	// TODO: obviously these shouldn't be called at exactly the same time...
	if(_flags.delegateWillBecomeFirstResponder) [delegate textRendererWillBecomeFirstResponder:self];
	if(_flags.delegateDidBecomeFirstResponder) [delegate textRendererDidBecomeFirstResponder:self];
	
	return YES;
}

- (BOOL)resignFirstResponder
{
	// TODO: obviously these shouldn't be called at exactly the same time...
	if(_flags.delegateWillResignFirstResponder) [delegate textRendererWillResignFirstResponder:self];
	[self resetSelection];
	if(_flags.delegateDidResignFirstResponder) [delegate textRendererDidResignFirstResponder:self];
	return YES;
}

// Services

- (id)validRequestorForSendType:(NSString *)sendType returnType:(NSString *)returnType
{
	if([sendType isEqualToString:NSStringPboardType] && !returnType) {
		if([[self selectedString] length] > 0)
			return self;
	}
	return [super validRequestorForSendType:sendType returnType:returnType];
}

- (BOOL)writeSelectionToPasteboard:(NSPasteboard *)pboard types:(NSArray *)types
{
    if(![types containsObject:NSStringPboardType])
        return NO;
	
	[pboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
    return [pboard setString:[self selectedString] forType:NSStringPboardType];
}

- (void)quickLookWithEvent:(NSEvent *)event
{
    NSInteger idx = [self stringIndexForEvent:event];
    NSAttributedString * string = [self attributedString];
    
    NSRange range = [string doubleClickAtIndex:idx];
    
    NSAttributedString * target = [string attributedSubstringFromRange:range];
    
    if (!target.length) return;
    
    NSRect rect = [self firstRectForCharacterRange:ABCFRangeFromNSRange(range)];
    NSPoint point = rect.origin;
    
    CGFloat descent, leading;
    
    AB_CTFrameGetTypographicBoundsForLineAtPosition(self.ctFrame, [self localPointForEvent:event], NULL, &descent, &leading);
    
    point.y += descent;
    //point.y += leading;
    
    point = [self.view convertPoint:point toView:self.view.nsView.rootView];
    
    [self.view.nsView showDefinitionForAttributedString:target atPoint:point];
}

@end
