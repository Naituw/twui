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

#import "TUILabel.h"
#import "TUIColor.h"
#import "TUIFont.h"
#import "TUINSView.h"
#import "TUIStringDrawing.h"
#import "TUITextRenderer.h"
#import "TUIView+Private.h"

@interface TUILabel ()
- (void)_recreateAttributedString;
@end

@implementation TUILabel

@synthesize renderer;
@synthesize text=_text;
@synthesize font=_font;
@synthesize textColor=_textColor;
@synthesize alignment=_alignment;
@synthesize lineBreakMode = _lineBreakMode;

- (id)initWithFrame:(CGRect)frame
{
	if((self = [super initWithFrame:frame])) {
		renderer = [[TUITextRenderer alloc] init];
		[self setTextRenderers:[NSArray arrayWithObjects:renderer, nil]];
		
		_lineBreakMode = TUILineBreakModeClip;
		_alignment = TUITextAlignmentLeft;
	}
	return self;
}


- (NSMenu *)menuForEvent:(NSEvent *)event
{
	NSMenu *m = [[NSMenu alloc] initWithTitle:@""];
	
	{
		NSMenuItem *i = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Copy",nil) action:@selector(copyText:) keyEquivalent:@""];
		[i setKeyEquivalent:@"c"];
		[i setKeyEquivalentModifierMask:NSCommandKeyMask];
		[i setTarget:self];
		[m addItem:i];
		
	}
	
	return m;
}
- (void)copyText:(id)sender
{
	[[NSPasteboard generalPasteboard] clearContents];
	[[NSPasteboard generalPasteboard] writeObjects:[NSArray arrayWithObjects:[renderer selectedString], nil]];
}
- (void)drawRect:(CGRect)rect
{
	if(renderer.attributedString == nil) {
		[self _recreateAttributedString];
	}
	
	[super drawRect:rect]; // draw background
	CGRect bounds = self.bounds;
    
    CGRect textFrame = CGRectMake(0, 0, bounds.size.width, bounds.size.height);
    
    if (self.verticalCenter)
    {
        CGSize textSize = [renderer sizeConstrainedToWidth:textFrame.size.width];
        textFrame = ABIntegralRectWithSizeCenteredInRect(textSize, textFrame);
        textFrame.origin.x = 0;
        textFrame.size.width = bounds.size.width;
    }
    
	renderer.frame = textFrame;
	[renderer draw];	
}

- (void)_update
{
	[self setNeedsDisplay];
}

- (NSAttributedString *)attributedString
{
	if(renderer.attributedString == nil) {
		[self _recreateAttributedString];
	}
	
	return renderer.attributedString;
}

- (void)setAttributedString:(NSAttributedString *)a
{
	renderer.attributedString = a;
	[self _update];
}

- (void)_recreateAttributedString
{
	if(_text == nil) return;
	
	TUIAttributedString *newAttributedString = [TUIAttributedString stringWithString:_text];
	if(_font != nil) newAttributedString.font = _font;
	if(_textColor != nil) newAttributedString.color = _textColor;
	[newAttributedString setAlignment:self.alignment lineBreakMode:self.lineBreakMode];
	self.attributedString = newAttributedString;
}

- (BOOL)isSelectable
{
	return _textLabelFlags.selectable;
}

- (void)setSelectable:(BOOL)b
{
	_textLabelFlags.selectable = b;
}

- (void)setText:(NSString *)text
{
	if(text == _text) return;
	
	_text = [text copy];
	
	self.attributedString = nil;
}

- (void)setFont:(TUIFont *)font
{
	if(font == _font) return;
	
	_font = font;
	
	self.attributedString = nil;
}

- (void)setTextColor:(TUIColor *)textColor
{
	if(textColor == _textColor) return;
	
	_textColor = textColor;
	
	self.attributedString = nil;
}

- (void)setAlignment:(TUITextAlignment)alignment
{
	if(alignment == _alignment) return;
	
	_alignment = alignment;
	
	self.attributedString = nil;
}

- (void)setLineBreakMode:(TUILineBreakMode)lineBreakMode
{
	if (lineBreakMode == _lineBreakMode) return;
	
	_lineBreakMode = lineBreakMode;
	
	self.attributedString = nil;
}

- (void)setVerticalCenter:(BOOL)verticalCenter
{
    if (verticalCenter == _verticalCenter) return;
    
    _verticalCenter = verticalCenter;
}

@end
