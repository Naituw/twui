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

#import "TUIAttributedString.h"
#import "TUICGAdditions.h"
#import "TUIColor.h"
#import "TUIFont.h"
#import "TUIStringDrawing.h"
#import "TUITextRenderer.h"

@implementation NSAttributedString (TUIStringDrawing)

- (TUITextRenderer *)ab_sharedTextRenderer
{
	static TUITextRenderer *t = nil;
	if(!t)
		t = [[TUITextRenderer alloc] init];
	return t;
}

- (CGSize)ab_sizeConstrainedToWidth:(CGFloat)width
{
	return [self ab_sizeConstrainedToSize:CGSizeMake(width, 2000)]; // big enough
}

- (CGSize)ab_sizeConstrainedToSize:(CGSize)size
{
    TUIFontMetrics metrics = TUIFontMetricsNull;
    if (self.length) {
        CTFontRef font = (__bridge CTFontRef)[self attribute:(NSString *)kCTFontAttributeName atIndex:0 effectiveRange:NULL];
        if (font) {
            metrics = TUIFontMetricsGetDefault(CTFontGetSize(font));
        }
    }
    
    TUITextRenderer *t = [self ab_sharedTextRenderer];
    t.attributedString = self;
    t.frame = CGRectMake(0, 0, size.width, size.height);
    t.textLayout.baselineFontMetrics = metrics;
    return t.textLayout.layoutSize;
}

- (CGSize)ab_size
{
	return [self ab_sizeConstrainedToSize:CGSizeMake(2000, 2000)]; // big enough
}

- (CGSize)ab_drawInRect:(CGRect)rect context:(CGContextRef)ctx verticalAlignment:(TUITextVerticalAlignment)verticalAlignment
{
    TUIFontMetrics metrics = TUIFontMetricsNull;
    if (self.length) {
        CTFontRef font = (__bridge CTFontRef)[self attribute:(NSString *)kCTFontAttributeName atIndex:0 effectiveRange:NULL];
        if (font) {
            metrics = TUIFontMetricsGetDefault(CTFontGetSize(font));
        }
    }

    TUITextRenderer *t = [self ab_sharedTextRenderer];
    t.attributedString = self;
    t.textLayout.baselineFontMetrics = metrics;
    t.frame = rect;
    t.verticalAlignment = verticalAlignment;
    [t drawInContext:ctx];
    return t.textLayout.layoutSize;
}

- (CGSize)ab_drawInRect:(CGRect)rect context:(CGContextRef)ctx
{
    return [self ab_drawInRect:rect context:ctx verticalAlignment:TUITextVerticalAlignmentTop];
}

- (CGSize)ab_drawInRect:(CGRect)rect
{
	return [self ab_drawInRect:rect context:TUIGraphicsGetCurrentContext()];
}

@end

@implementation NSString (TUIStringDrawing)

#if TARGET_OS_MAC

- (CGSize)ab_sizeWithFont:(TUIFont *)font
{
	TUIAttributedString *s = [TUIAttributedString stringWithString:self];
	s.font = font;
	return [s ab_size];
}

- (CGSize)ab_sizeWithFont:(TUIFont *)font constrainedToSize:(CGSize)size
{
	TUIAttributedString *s = [TUIAttributedString stringWithString:self];
	s.font = font;
	return [s ab_sizeConstrainedToSize:size];
}

//- (CGSize)drawInRect:(CGRect)rect withFont:(TUIFont *)font lineBreakMode:(TUILineBreakMode)lineBreakMode alignment:(TUITextAlignment)alignment
//{
//	return [self ab_drawInRect:rect withFont:font lineBreakMode:lineBreakMode alignment:alignment];
//}

#endif

- (CGSize)ab_drawInRect:(CGRect)rect color:(TUIColor *)color font:(TUIFont *)font
{
	TUIAttributedString *s = [TUIAttributedString stringWithString:self];
	s.color = color;
	s.font = font;
	return [s ab_drawInRect:rect];
}

- (CGSize)ab_drawInRect:(CGRect)rect withFont:(TUIFont *)font lineBreakMode:(TUILineBreakMode)lineBreakMode alignment:(TUITextAlignment)alignment
{
    return [self ab_drawInRect:rect withFont:font lineBreakMode:lineBreakMode alignment:alignment verticalAlignment:TUITextVerticalAlignmentTop];
}

- (CGSize)ab_drawInRect:(CGRect)rect withFont:(TUIFont *)font lineBreakMode:(TUILineBreakMode)lineBreakMode alignment:(TUITextAlignment)alignment verticalAlignment:(TUITextVerticalAlignment)verticalAlignment
{
    TUIAttributedString *s = [TUIAttributedString stringWithString:self];
    [s addAttribute:(NSString *)kCTForegroundColorFromContextAttributeName
              value:(id)[NSNumber numberWithBool:YES]
              range:NSMakeRange(0, [self length])];
    [s setAlignment:alignment lineBreakMode:lineBreakMode];
    s.font = font;
    return [s ab_drawInRect:rect context:TUIGraphicsGetCurrentContext() verticalAlignment:verticalAlignment];
}

@end
