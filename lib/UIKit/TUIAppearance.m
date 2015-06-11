//
//  TUIAppearance.m
//  TwUI
//
//  Created by Wutian on 14/8/3.
//
//

#import "TUIAppearance.h"

@interface TUIAppearance ()

@property (copy) NSString * name;

@end

@implementation TUIAppearance

- (instancetype)initWithAppearanceNamed:(NSString *)name
{
    if (self = [self init]) {
        self.name = name;
    }
    return self;
}

+ (instancetype)appearanceNamed:(NSString *)name
{
    if ([name isEqual:TUIAppearanceNameDark]) {
        return [self darkAppearance];
    } else if ([name isEqual:TUIAppearanceNameLight]) {
        return [self lightAppearance];
    }
    
    return [[self alloc] initWithAppearanceNamed:name];
}

- (BOOL)isEqual:(TUIAppearance *)object
{
    if (self == object) {
        return YES;
    }
    
    if (![object isKindOfClass:[TUIAppearance class]]) {
        return NO;
    }
    
    return [self.name isEqual:object.name];
}

@end

NSString *const TUIAppearanceNameDark = @"TUIAppearanceNameDark";
NSString *const TUIAppearanceNameLight = @"TUIAppearanceNameLight";

@implementation TUIAppearance (Convenience)

+ (instancetype)darkAppearance
{
    static TUIAppearance * _appearance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _appearance = [[self alloc] initWithAppearanceNamed:TUIAppearanceNameDark];
    });
    return _appearance;
}

+ (instancetype)lightAppearance
{
    static TUIAppearance * _appearance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _appearance = [[self alloc] initWithAppearanceNamed:TUIAppearanceNameLight];
    });
    return _appearance;
}

@end
